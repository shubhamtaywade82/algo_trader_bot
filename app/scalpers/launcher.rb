# frozen_string_literal: true

require 'yaml'

module Scalpers
  # Boots the stock/options scalper lanes based on environment flags and keeps
  # them running alongside the Rails server. Each lane wraps the same pipeline
  # used by the previous bin scripts (Feed runner ➜ bars loop ➜ scalper runner)
  # but is now driven by `ENABLE_STOCK_SCALPER` / `ENABLE_OPTIONS_SCALPER`.
  class Launcher
    LaneSpec = Struct.new(
      :key,
      :name,
      :config_path,
      :config_key,
      :env_key,
      :default_segment,
      :default_exchange,
      keyword_init: true
    )

    TRUTHY_VALUES = %w[1 true yes on].freeze
    OPTION_UNDERLYINGS = %w[NIFTY BANKNIFTY SENSEX].freeze

    LANES = {
      stocks: LaneSpec.new(
        key: :stocks,
        name: 'StockScalper',
        config_path: Rails.root.join('config/scalper.stocks.yml'),
        config_key: :stocks,
        env_key: 'ENABLE_STOCK_SCALPER',
        default_segment: :equity,
        default_exchange: :nse
      ),
      options: LaneSpec.new(
        key: :options,
        name: 'OptionsScalper',
        config_path: Rails.root.join('config/scalper.options.yml'),
        config_key: :options,
        env_key: 'ENABLE_OPTIONS_SCALPER',
        default_segment: :index,
        default_exchange: nil
      )
    }.freeze

    class << self
      def instance(logger: Rails.logger)
        @instance ||= new(logger: logger)
      end

      def start_enabled(async: true, logger: Rails.logger)
        instance(logger: logger).start_enabled(async: async)
      end
    end

    def initialize(logger: Rails.logger)
      @logger = logger
      @lanes = {}
      @shutdown_registered = false
      @mutex = Mutex.new
    end

    def start_enabled(async: true)
      started = false
      LANES.each_key do |key|
        next unless env_enabled?(key)

        started |= start_lane(key, async: async)
      end
      register_shutdown! if started && async
      started
    end

    def start_lane(key, async: true)
      lane_spec = LANES.fetch(key)
      return false if lane_running?(key)

      config = load_config(lane_spec.config_path)
      return false unless config

      shared_cfg = config[:shared] || {}
      lane_cfg = config[lane_spec.config_key] || {}
      resolver = Instruments::Resolver.new

      watchlist = build_watchlist(key, lane_cfg[:watchlist], resolver, lane_spec)

      if watchlist.empty?
        @logger.warn("[#{lane_spec.name}] No instruments resolved from watchlist. Skipping.")
        return false
      end

      infra = Scalpers::Base::Infra.new(shared_cfg)
      feed_runner = Feed::Runner.new(watchlist: watchlist, logger: @logger)

      bars_loop = Bars::FetchLoop.new(
        watchlist: watchlist,
        infra: infra,
        poll_interval: lane_cfg[:bars_poll_interval] || 45,
        intervals: lane_cfg[:intervals] || %w[1 5],
        logger: @logger
      )
      scalper_runner = build_runner(key, infra, watchlist, lane_cfg, shared_cfg)

      feed_runner.start!
      bars_loop.start!

      handle = {
        spec: lane_spec,
        infra: infra,
        feed: feed_runner,
        bars: bars_loop,
        runner: scalper_runner
      }

      if async
        thread = Thread.new do
          begin
            Thread.current.name = lane_spec.name if Thread.current.respond_to?(:name=)
          rescue StandardError
            # ignore platforms without thread naming support
          end
          @logger.info("[#{lane_spec.name}] runner thread started.")
          begin
            scalper_runner.start!
          rescue StandardError => e
            @logger.error("[#{lane_spec.name}] runner crashed: #{e.class} #{e.message}")
            log_backtrace(e)
          end
        end
        handle[:thread] = thread
        @logger.info("[#{lane_spec.name}] started (async)")
      else
        setup_signal_traps(handle)
        @logger.info("[#{lane_spec.name}] started (blocking)")
      end

      @mutex.synchronize { @lanes[key] = handle }
      register_shutdown! if async

      if async
        true
      else
        begin
          scalper_runner.start!
        rescue Interrupt
          # graceful shutdown will be handled by trap
        ensure
          stop_lane(key)
        end
        false
      end
    rescue StandardError => e
      @logger.error("[#{lane_spec.name}] boot failed: #{e.class} #{e.message}")
      log_backtrace(e)
      stop_lane_resources(feed_runner: feed_runner, bars_loop: bars_loop, runner: scalper_runner)
      false
    end

    def stop_all
      handles = nil
      @mutex.synchronize do
        handles = @lanes.dup
        @lanes.clear
      end
      handles.each_key { |lane_key| stop_lane(lane_key, handles[lane_key]) }
    end

    private

    def stop_lane(key, handle = nil)
      handle ||= @mutex.synchronize { @lanes.delete(key) }
      return unless handle

      spec = handle[:spec]
      thread = handle[:thread]

      safe_stop(handle[:runner], :stop!, spec.name)
      safe_stop(handle[:feed], :stop!, spec.name)
      safe_stop(handle[:bars], :stop!, spec.name)

      thread&.join(5)
    end

    def safe_stop(target, method, label)
      target&.public_send(method)
    rescue StandardError => e
      @logger.error("[#{label}] #{method} failed: #{e.class} #{e.message}")
    end

    def setup_signal_traps(handle)
      spec = handle[:spec]
      %w[INT TERM].each do |signal|
        trap(signal) do
          @logger.info("[#{spec.name}] received #{signal}, shutting down...")
          stop_all
        end
      end
    rescue ArgumentError
      # signal not supported on this platform (e.g., windows) — ignore
    end

    def build_runner(key, infra, watchlist, lane_cfg, shared_cfg)
      case key
      when :stocks
        Scalpers::Stocks::Runner.new(
          infra: infra,
          watchlist: watchlist,
          logger: @logger,
          poll_interval: lane_cfg[:poll_interval] || 20,
          idempotency_ttl: lane_cfg[:idempotency_ttl] || 120,
          cash_balance: lane_cfg[:cash_balance] || shared_cfg.dig(:sizing, :capital)
        )
      when :options
        Scalpers::Options::Runner.new(
          infra: infra,
          watchlist: watchlist,
          logger: @logger,
          poll_interval: lane_cfg[:poll_interval] || 20,
          idempotency_ttl: lane_cfg[:idempotency_ttl] || 90,
          cash_balance: lane_cfg[:cash_balance] || shared_cfg.dig(:sizing, :capital)
        )
      else
        raise ArgumentError, "Unknown scalper lane: #{key}"
      end
    end

    def build_watchlist(key, rows, resolver, spec)
      case key
      when :stocks then build_stocks_watchlist(rows, resolver, spec)
      when :options then build_options_watchlist(rows, resolver, spec)
      else []
      end
    end

    def build_stocks_watchlist(rows, resolver, spec)
      Array(rows).filter_map do |row|
        cfg = row.to_h.deep_symbolize_keys
        instrument = resolver.call(
          symbol: cfg[:symbol],
          exchange: cfg.fetch(:exchange, spec.default_exchange),
          segment: cfg[:segment] || spec.default_segment,
          security_id: cfg[:security_id]
        )

        unless instrument
          @logger.warn("[#{spec.name}] Instrument not found: #{cfg[:symbol]}")
          next
        end

        cfg[:instrument] = instrument
        cfg[:symbol] = instrument.symbol_name
        cfg
      end
    end

    def build_options_watchlist(rows, resolver, spec)
      Array(rows).filter_map do |row|
        cfg = row.to_h.deep_symbolize_keys
        normalized = normalize_symbol(cfg[:symbol])
        hints = Instruments::Resolver::INDEX_ALIASES[normalized]
        instrument = resolver.call(
          symbol: cfg[:symbol],
          exchange: cfg.fetch(:exchange, hints&.dig(:exchange) || spec.default_exchange),
          segment: cfg[:segment] || hints&.dig(:segment) || spec.default_segment,
          security_id: cfg[:security_id]
        )
        unless instrument
          @logger.warn("[#{spec.name}] Instrument not found: #{cfg[:symbol]}")
          next
        end

        unless allowed_options_underlying?(instrument)
          @logger.warn("[#{spec.name}] Unsupported underlying: #{instrument.symbol_name}")
          next
        end

        cfg[:instrument] = instrument
        cfg[:symbol] = instrument.symbol_name
        cfg
      end
    end

    def allowed_options_underlying?(instrument)
      code = normalize_symbol(instrument.symbol_name) || normalize_symbol(instrument.display_name)
      OPTION_UNDERLYINGS.include?(code)
    end

    def env_enabled?(key)
      spec = LANES.fetch(key)
      truthy?(ENV.fetch(spec.env_key, nil))
    end

    def lane_running?(key)
      @mutex.synchronize { @lanes.key?(key) }
    end

    def register_shutdown!
      return if @shutdown_registered

      @shutdown_registered = true
      at_exit { stop_all }
    end

    def truthy?(value)
      TRUTHY_VALUES.include?(value.to_s.strip.downcase)
    end

    def normalize_symbol(value)
      value.to_s.upcase.delete(' ')
    end

    def load_config(path)
      YAML.load_file(path).deep_symbolize_keys
    rescue Errno::ENOENT
      @logger.error("[Scalpers::Launcher] Config not found: #{path}")
      nil
    rescue StandardError => e
      @logger.error("[Scalpers::Launcher] Failed to load #{path}: #{e.class} #{e.message}")
      log_backtrace(e)
      nil
    end

    def log_backtrace(error)
      return unless error&.backtrace && @logger.respond_to?(:error)

      @logger.error(error.backtrace.first(5).join("\n"))
    end

    def stop_lane_resources(feed_runner:, bars_loop:, runner:)
      safe_stop(runner, :stop!, 'ScalperLane')
      safe_stop(feed_runner, :stop!, 'FeedRunner')
      safe_stop(bars_loop, :stop!, 'BarsLoop')
    end
  end
end
