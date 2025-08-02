module Indicators
  class OrderBlock
    def initialize(series)
      @series = series
    end

    def bullish_order_blocks
      @series.each_cons(3).with_index.filter_map do |(prev, curr, next_c), i|
        { index: i + 1, low: curr.low, high: curr.high } if curr.bearish? && next_c.bullish? && next_c.close > prev.high
      end
    end

    def bearish_order_blocks
      @series.each_cons(3).with_index.filter_map do |(prev, curr, next_c), i|
        { index: i + 1, low: curr.low, high: curr.high } if curr.bullish? && next_c.bearish? && next_c.close < prev.low
      end
    end
  end
end
