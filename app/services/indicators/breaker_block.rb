module Indicators
  class BreakerBlock
    def initialize(series)
      @series = series
      @candles = series.candles
    end

    def identify
      breakers = []

      @candles.each_with_index do |candle, i|
        next if i < 5

        prev = @candles[i - 1]
        before_prev = @candles[i - 2]

        # 1️⃣ Detect bullish breaker (failed bullish OB -> turns bearish)
        if bullish_ob_fail?(before_prev, prev, candle)
          breakers << {
            type: :bearish_breaker,
            breaker_zone: { high: before_prev.high, low: before_prev.low },
            broken_at: candle.timestamp,
            retest_pending: true
          }
        end

        # 2️⃣ Detect bearish breaker (failed bearish OB -> turns bullish)
        next unless bearish_ob_fail?(before_prev, prev, candle)

        breakers << {
          type: :bullish_breaker,
          breaker_zone: { high: before_prev.high, low: before_prev.low },
          broken_at: candle.timestamp,
          retest_pending: true
        }
      end

      breakers
    end

    private

    def bullish_ob_fail?(ob, next_candle, breaker_candle)
      ob.bullish? &&
        next_candle.low < ob.low &&         # OB invalidated
        breaker_candle.close > ob.high      # Breaker confirmation
    end

    def bearish_ob_fail?(ob, next_candle, breaker_candle)
      ob.bearish? &&
        next_candle.high > ob.high &&       # OB invalidated
        breaker_candle.close < ob.low       # Breaker confirmation
    end
  end
end