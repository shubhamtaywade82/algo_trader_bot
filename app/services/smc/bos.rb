# SMC Component: Break of Structure (BOS)
module Smc
  class Bos < ApplicationService
    def initialize(series:)
      @series = series
      @candles = series.candles
    end

    def call
      index = candles.size - 2
      return false if index < 4

      # Detect BOS: Higher High followed by higher low (bullish) or Lower Low + Lower High (bearish)
      last_high = candles[index].high
      prev_high = candles[index - 2].high
      last_low  = candles[index].low
      prev_low  = candles[index - 2].low

      bullish_bos = last_high > prev_high && candles[index + 1].low > prev_low
      bearish_bos = last_low < prev_low && candles[index + 1].high < prev_high

      bullish_bos || bearish_bos
    end

    private

    attr_reader :series, :candles
  end
end
