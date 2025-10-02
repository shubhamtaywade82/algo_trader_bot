# frozen_string_literal: true

module RateLimiter
  # Simple in-process token bucket to keep REST usage under broker QPS limits.
  class TokenBucket
    def initialize(rate:, burst:)
      raise ArgumentError, 'rate must be positive' unless rate.to_f.positive?
      raise ArgumentError, 'burst must be positive' unless burst.to_f.positive?

      @rate = rate.to_f
      @capacity = burst.to_f
      @tokens = @capacity
      @last_refill = Time.now
      @mutex = Mutex.new
    end

    def consume!(tokens = 1.0)
      raise ArgumentError, 'tokens must be positive' unless tokens.to_f.positive?

      @mutex.synchronize do
        refill!
        if @tokens >= tokens
          @tokens -= tokens
          return true
        end

        wait_time = (tokens - @tokens) / @rate
        sleep(wait_time) if wait_time.positive?
        refill!
        if @tokens >= tokens
          @tokens -= tokens
          true
        else
          false
        end
      end
    end

    private

    def refill!
      now = Time.now
      elapsed = now - @last_refill
      return if elapsed <= 0

      new_tokens = elapsed * @rate
      @tokens = [@tokens + new_tokens, @capacity].min
      @last_refill = now
    end
  end
end
