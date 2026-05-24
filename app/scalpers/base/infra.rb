# frozen_string_literal: true

require 'concurrent'

module Scalpers
  module Base
    # Dependency container / facade that wires together the shared services needed
    # by the scalper lanes. Keeps construction and wiring in one place so bin
    # scripts can stay lean.
    class Infra
      attr_reader :engine, :risk_profile, :sizing, :token_bucket, :backoff, :ltp_cache, :bars_cache

      def initialize(config = {})
        raw = config.respond_to?(:to_h) ? config.to_h : {}
        @config = raw.deep_symbolize_keys

        @engine = Engine.new(@config[:engine] || {})
        @risk_profile = RiskProfile.new(@config[:risk] || {})
        @sizing = Sizing.new(@config[:sizing] || {})

        limiter_cfg = (@config[:rate_limiter] || {})
        @token_bucket = RateLimiter::TokenBucket.new(
          rate: limiter_cfg[:qps] || 6,
          burst: limiter_cfg[:burst] || 10
        )
        @backoff = RateLimiter::Backoff.new(
          base_delay: limiter_cfg[:base_delay] || 0.5,
          max_delay: limiter_cfg[:max_delay] || 5.0
        )
        @min_call_gap = limiter_cfg[:min_spacing] || 0.25
        @spacing_mutex = Mutex.new
        @last_call_ts = Process.clock_gettime(Process::CLOCK_MONOTONIC) - @min_call_gap.to_f

        @ltp_cache = Stores::LtpCache.instance
        @bars_cache = Stores::BarsCache.instance

        @trading_enabled = Concurrent::AtomicBoolean.new(true)
        @kill_switch_reason = Concurrent::AtomicReference.new('ok')
      end

      def trading_enabled?
        @trading_enabled.true?
      end

      def disable_trading!(reason)
        @kill_switch_reason.set(reason)
        @trading_enabled.make_false
      end

      def enable_trading!
        @kill_switch_reason.set('ok')
        @trading_enabled.make_true
      end

      def kill_switch_reason
        @kill_switch_reason.get
      end

      # Execute a REST call while respecting rate limits and applying retry/backoff
      def with_api_guard
        raise ArgumentError, 'block required' unless block_given?

        loop do
          respect_call_spacing
          token_bucket.consume!
          begin
            result = yield
            @backoff.reset!
            @backoff.register_attempt!(success: true)
            return result
          rescue RateLimiter::Backoff::RetryableError => e
            Rails.logger.warn("[Scalpers::Base::Infra] retryable error: #{e.message}")
            @backoff.register_attempt!
            sleep(@backoff.next_interval)
          rescue RateLimiter::Backoff::FatalError => e
            Rails.logger.error("[Scalpers::Base::Infra] fatal error: #{e.message}")
            disable_trading!("fatal_error: #{e.message}")
            @backoff.register_attempt!
            raise
          rescue DhanHQ::RateLimitError, DhanHQ::NetworkError => e
            Rails.logger.warn("[Scalpers::Base::Infra] broker throttled/network issue: #{e.message}")
            @backoff.register_attempt!
            sleep(@backoff.next_interval)
          rescue StandardError => e
            if auth_error?(e)
              Rails.logger.error("[Scalpers::Base::Infra] authentication error: #{e.message}")
              disable_trading!('invalid_credentials')
              raise Scalpers::Errors::InvalidCredentials, e.message
            end

            Rails.logger.error("[Scalpers::Base::Infra] unexpected error: #{e.message}")
            @backoff.register_attempt!
            sleep(@backoff.next_interval)
          end
        end
      end

      private

      AUTH_ERROR_CODES = %w[DH-901 DH-902 DH-903 DH-807 DH-808 DH-809 DH-810].freeze

      def respect_call_spacing
        gap = @min_call_gap.to_f
        return if gap <= 0

        @spacing_mutex.synchronize do
          now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          wait = gap - (now - @last_call_ts)
          sleep(wait) if wait.positive?
          @last_call_ts = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        end
      end

      def auth_error?(error)
        return true if error.is_a?(Scalpers::Errors::InvalidCredentials)

        message = error.message.to_s
        AUTH_ERROR_CODES.any? { |code| message.include?(code) }
      end
    end
  end
end
