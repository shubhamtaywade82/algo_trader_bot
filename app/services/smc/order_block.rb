# frozen_string_literal: true

module Smc
  class OrderBlock < ApplicationService
    def initialize(series:)
      @series = series
      @candles = series.candles
    end

    def call
      return false if candles.size < 10

      last_index = candles.size - 1
      lookback = 10

      (last_index - lookback).upto(last_index - 2) do |i|
        curr = candles[i]
        nxt  = candles[i + 1]

        # Bullish Order Block: Last bearish candle before strong bullish candle
        return true if curr.bearish? && nxt.bullish? && nxt.close > nxt.open + series.atr && price_respected_order_block?(curr.low, :bullish)

        # Bearish Order Block: Last bullish candle before strong bearish candle
        return true if curr.bullish? && nxt.bearish? && nxt.close < nxt.open - series.atr && price_respected_order_block?(curr.high, :bearish)
      end

      false
    end

    private

    attr_reader :series, :candles

    def price_respected_order_block?(level, direction)
      last = candles.last
      if direction == :bullish
        last.low >= level
      else
        last.high <= level
      end
    end
  end
end
