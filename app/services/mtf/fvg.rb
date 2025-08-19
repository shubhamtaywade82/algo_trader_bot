# frozen_string_literal: true

module Mtf
  class FVG
    Gap = Struct.new(:dir, :i, :hi, :lo, keyword_init: true) # dir :up/:down, i = middle bar index

    # Classic 3-candle FVG:
    #  up: low[i+1] > high[i-1]
    # down: high[i+1] < low[i-1]
    def self.scan(series, lookback: 30)
      out = []
      bars = series.candles
      return out if bars.size < 3

      start = [0, bars.size - lookback - 1].max
      (start...(bars.size - 1)).each do |i|
        prev = begin
          bars[i - 1]
        rescue StandardError
          nil
        end
        nxt = begin
          bars[i + 1]
        rescue StandardError
          nil
        end
        next unless prev && nxt

        if nxt.low > prev.high
          out << Gap.new(dir: :up, i: i, hi: prev.high, lo: nxt.low)
        elsif nxt.high < prev.low
          out << Gap.new(dir: :down, i: i, hi: nxt.high, lo: prev.low)
        end
      end
      out
    end

    def self.price_in_gap?(gap, price)
      return false unless gap

      price > gap.hi && price < gap.lo
    end
  end
end
