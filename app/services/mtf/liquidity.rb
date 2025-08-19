# frozen_string_literal: true

module Mtf
  class Liquidity
    Pool = Struct.new(:kind, :i1, :i2, :level, keyword_init: true) # :eq_highs/:eq_lows

    def self.equal_highs(series, tol_pct: 0.0005, lookback: 40)
      scan(series, :high, :eq_highs, tol_pct: tol_pct, lookback: lookback)
    end

    def self.equal_lows(series, tol_pct: 0.0005, lookback: 40)
      scan(series, :low, :eq_lows, tol_pct: tol_pct, lookback: lookback)
    end

    def self.scan(series, field, kind, tol_pct:, lookback:)
      bars = series.candles.last(lookback)
      out  = []
      (0...(bars.size - 1)).each do |i|
        a = bars[i].public_send(field)
        b = bars[i + 1].public_send(field)
        next if [a, b].any?(&:nil?)

        tol = [a, b].max * tol_pct
        out << Pool.new(kind: kind, i1: i, i2: i + 1, level: (a + b) / 2.0) if (a - b).abs <= tol
      end
      out
    end
  end
end
v