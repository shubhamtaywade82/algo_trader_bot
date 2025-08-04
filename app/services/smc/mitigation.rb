# frozen_string_literal: true

module Smc
  class Mitigation < ApplicationService
    def initialize(series:)
      @series = series
      @candles = series.candles
    end

    def call
      return false if candles.size < 20

      # Reuse previously defined Order Blocks
      order_blocks = Smc::OrderBlock.call(series: series)
      return false if order_blocks.blank?

      # Pick the last known OB zone
      ob = order_blocks.last
      return false unless ob[:index] && ob[:type] && ob[:range]

      # Only consider mitigation attempts that come after 3 candles from OB
      mitigation_index = ob[:index] + 3
      return false if candles.size <= mitigation_index

      # Look for price touching or reacting from OB zone in later candles
      candles[mitigation_index..].each do |candle|
        if ob[:type] == :bullish
          return true if candle.low <= ob[:range][:low] && candle.close > ob[:range][:low]
        elsif ob[:type] == :bearish
          return true if candle.high >= ob[:range][:high] && candle.close < ob[:range][:high]
        end
      end

      false
    rescue StandardError => e
      Rails.logger.error("Mitigation check failed: #{e.message}")
      false
    end

    private

    attr_reader :series, :candles
  end
end