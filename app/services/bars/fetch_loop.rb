# frozen_string_literal: true

require 'concurrent'

module Bars
  # Periodically refreshes intraday bars (1m/5m) for the scalper watchlist.
  class FetchLoop
    DEFAULTS = {
      poll_interval: 60,
      stagger_delay: 0.25,
      max_candles: 180,
      intervals: %w[1 5]
    }.freeze

    def initialize(watchlist:, infra:, bars_cache: Stores::BarsCache.instance, logger: Rails.logger, **opts)
      @watchlist = Array(watchlist)
      @infra = infra
      @bars_cache = bars_cache
      @logger = logger
      @config = DEFAULTS.merge(opts.deep_symbolize_keys)
      @running = Concurrent::AtomicBoolean.new(false)
      @thread = nil
    end

    def start!
      return self if @running.true?

      @running.make_true
      @thread = Thread.new { loop_body }
      self
    end

    def stop!
      @running.make_false
      @thread&.join(1)
      @thread = nil
      self
    end

    private

    def loop_body
      while @running.true?
        fetch_cycle
        sleep(@config[:poll_interval].to_f)
      end
    rescue StandardError => e
      @logger.error("[Bars::FetchLoop] crashed: #{e.message}")
      retry if @running.true?
    end

    def fetch_cycle
      @watchlist.each do |entry|
        instrument = entry[:instrument]
        next unless instrument

        @config[:intervals].each do |interval|
          fetch_and_store(instrument, interval)
          sleep(@config[:stagger_delay].to_f)
        end
      end
    end

    def fetch_and_store(instrument, interval)
      response = @infra.with_api_guard do
        instrument.intraday_ohlc(interval: interval, days: 5)
      end
      return unless response

      series = CandleSeries.new(symbol: instrument.symbol_name, interval: interval)
      series.load_from_raw(response)
      series.candles.shift([series.candles.size - @config[:max_candles], 0].max)

      @bars_cache.write(
        segment: instrument.exchange_segment,
        security_id: instrument.security_id,
        interval: interval,
        series: series
      )
    rescue StandardError => e
      @logger.warn("[Bars::FetchLoop] failed to fetch #{instrument.symbol_name} #{interval}m: #{e.message}")
    end
  end
end
