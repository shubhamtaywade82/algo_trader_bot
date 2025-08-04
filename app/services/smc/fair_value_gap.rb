# frozen_string_literal: true

module Smc
  class FairValueGap < ApplicationService
    def initialize(series:)
      @series = series
      @candles = series.candles
    end

    def call
      return false if candles.size < 3

      # Use last 3 candles
      c1, c2, c3 = candles[-3..]

      bullish_gap = c3.low > c1.high
      bearish_gap = c3.high < c1.low

      bullish_gap || bearish_gap
    end

    private

    attr_reader :series, :candles
  end
end