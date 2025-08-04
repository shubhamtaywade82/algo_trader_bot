# SMC Component: Change of Character (CHOCH)
module Smc
  class Choch < ApplicationService
    def initialize(series:)
      @series = series
      @candles = series.candles
    end

    def call
      return false if candles.size < 10

      recent = candles.last(5)
      prev = candles.last(10)[0...5]

      bullish_choch = recent.first.low > prev.map(&:low).max && recent.last.close > recent.first.open
      bearish_choch = recent.first.high < prev.map(&:high).min && recent.last.close < recent.first.open

      bullish_choch || bearish_choch
    end

    private

    attr_reader :series, :candles
  end
end