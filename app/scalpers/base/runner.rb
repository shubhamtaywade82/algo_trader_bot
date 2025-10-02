# frozen_string_literal: true

require 'concurrent'

module Scalpers
  module Base
    # Shared orchestration loop used by the stock and options scalpers. It expects
    # lane-specific policy, sizer and executor objects to be injected, which keeps
    # the loop generic while letting each lane customise order placement.
    class Runner

      Decision = Struct.new(
        :instrument,
        :symbol,
        :direction,
        :action,
        :kind,
        :risk_per_unit,
        :entry_price,
        :stop_loss,
        :take_profit,
        :metadata,
        :quantity,
        :expected_loss,
        keyword_init: true
      )

      DEFAULTS = {
        poll_interval: 15,
        idempotency_ttl: 90,
        cash_balance: 1_000_000.0
      }.freeze

      def initialize(infra:, policy:, sizer:, executor:, watchlist:, logger: Rails.logger, **opts)
        @infra = infra
        @policy = policy
        @sizer = sizer
        @executor = executor
        @watchlist = Array(watchlist)
        @logger = logger
        @config = DEFAULTS.merge(opts.deep_symbolize_keys)
        @running = Concurrent::AtomicBoolean.new(false)
        @decision_cache = Concurrent::Map.new
      end

      def start!
        return self if @running.true?

        @running.make_true
        @logger.info('[Scalpers::Base::Runner] starting loop')
        while @running.true?
          begin
            run_once
          rescue StandardError => e
            @logger.error("[Scalpers::Base::Runner] run_once failed: #{e.class} #{e.message}")
          ensure
            sleep(@config[:poll_interval].to_f)
          end
        end
        self
      end

      def stop!
        @running.make_false
      end

      def run_once(now: Time.zone.now)
        prune_decisions!(now)
        return unless @infra.trading_enabled?

        @watchlist.each do |entry|
          instrument = entry[:instrument]
          next unless instrument

          series_1m = @infra.bars_cache.series(segment: instrument.exchange_segment, security_id: instrument.security_id, interval: '1')
          series_5m = @infra.bars_cache.series(segment: instrument.exchange_segment, security_id: instrument.security_id, interval: '5')
          next unless series_1m && series_5m

          signal = @infra.engine.signal_for(symbol: instrument.symbol_name || instrument.display_name, series_1m:, series_5m:)
          next unless signal

          ltp = @infra.ltp_cache.ltp(segment: instrument.exchange_segment, security_id: instrument.security_id)
          ltp ||= instrument.respond_to?(:ltp) ? instrument.ltp : nil
          decision = @policy.build_decision(signal:, instrument:, ltp:, config: entry)
          next unless decision&.is_a?(Decision)

          sized_decision = @sizer.apply(decision:, cash_balance: available_cash(entry), config: entry)
          next unless sized_decision&.quantity.to_i.positive?

          expected_loss = sized_decision.risk_per_unit.to_f * sized_decision.quantity.to_i
          allowed, reason = @infra.risk_profile.allow_entry?(symbol: sized_decision.symbol, expected_loss_rupees: expected_loss)
          unless allowed
            @logger.info("[Scalpers::Base::Runner] skip #{sized_decision.symbol} - risk gate: #{reason}")
            next
          end

          bar_ts = series_1m.candles.last&.timestamp || now
          if duplicate_decision?(sized_decision, bar_ts)
            @logger.debug("[Scalpers::Base::Runner] duplicate decision for #{sized_decision.symbol} @ #{bar_ts}")
            next
          end

          sized_decision.expected_loss = expected_loss
          if @executor.execute(decision: sized_decision, infra: @infra, config: entry)
            record_decision!(sized_decision, bar_ts, now)
            @logger.info("[Scalpers::Base::Runner] order dispatched for #{sized_decision.symbol}")
          end
        end
      end

      private

      def available_cash(entry)
        entry[:cash_balance].presence || @config[:cash_balance]
      end

      def duplicate_decision?(decision, bar_ts)
        key = cache_key(decision)
        existing = @decision_cache[key]
        return false unless existing

        existing[:bar_ts] == bar_ts
      end

      def record_decision!(decision, bar_ts, now)
        key = cache_key(decision)
        @decision_cache[key] = { bar_ts: bar_ts, recorded_at: now }
      end

      def prune_decisions!(now)
        ttl = @config[:idempotency_ttl].to_i
        return if ttl <= 0

        @decision_cache.each_pair do |key, payload|
          next unless payload[:recorded_at]
          next unless now - payload[:recorded_at] > ttl

          @decision_cache.delete(key)
        end
      end

      def cache_key(decision)
        [decision.symbol, decision.direction, decision.kind].join(':')
      end
    end
  end
end
