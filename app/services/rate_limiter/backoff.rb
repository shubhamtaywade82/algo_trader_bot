# frozen_string_literal: true

require 'concurrent'

module RateLimiter
  class Backoff
    class RetryableError < StandardError; end
    class FatalError < StandardError; end

    def initialize(base_delay:, max_delay:, multiplier: 2.0, jitter: 0.2)
      @base_delay = base_delay.to_f
      @max_delay = max_delay.to_f
      @multiplier = multiplier.to_f
      @jitter = jitter.to_f
      @attempts = Concurrent::AtomicFixnum.new(0)
    end

    def next_interval
      attempt = @attempts.value
      delay = [@base_delay * (@multiplier**attempt), @max_delay].min
      jitter_component = delay * @jitter * rand
      delay + jitter_component
    ensure
      @attempts.increment
    end

    def register_attempt!(success: false)
      reset! if success
    end

    def reset!
      @attempts.value = 0
    end
  end
end
