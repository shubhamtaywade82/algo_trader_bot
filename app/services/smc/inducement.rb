# frozen_string_literal: true

module Smc
  class Inducement < ApplicationService
    def initialize(series:)
      @series = series
      @candles = series.candles
    end

    def call
      return false if candles.size < 20

      lookback = 15
      current = candles.last
      past = candles.last(lookback + 1)[0...lookback]

      inducement_up = false
      inducement_down = false

      # False breakout above previous highs (trap long buyers)
      highest_past_high = past.map(&:high).max
      inducement_up = true if current.high > highest_past_high && current.close < highest_past_high && current.bearish?

      # False breakdown below previous lows (trap short sellers)
      lowest_past_low = past.map(&:low).min
      inducement_down = true if current.low < lowest_past_low && current.close > lowest_past_low && current.bullish?

      inducement_up || inducement_down
    rescue StandardError => e
      Rails.logger.error("SMC::Inducement error: #{e.message}")
      false
    end

    private

    attr_reader :series, :candles
  end
end
