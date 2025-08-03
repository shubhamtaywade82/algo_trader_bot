module Indicators
  class Supertrend < ApplicationService
    attr_reader :series, :period, :multiplier, :supertrend_values

    def initialize(series:, period: 10, multiplier: 3.0)
      @series = series
      @period = period
      @multiplier = multiplier
      @supertrend_values = []
    end

    def call
      atr = calculate_atr
      return [] if atr.empty?

      supertrend = []
      trend = [] # :bullish or :bearish

      series.each_with_index do |candle, i|
        next if i < period

        hl2 = (candle.high + candle.low) / 2.0
        upper_band = hl2 + (multiplier * atr[i])
        lower_band = hl2 - (multiplier * atr[i])

        if i == period
          supertrend[i] = upper_band
          trend[i] = :bearish
        else
          prev_close = series[i - 1].close
          prev_supertrend = supertrend[i - 1]

          if prev_close <= supertrend[i - 1]
            supertrend[i] = [upper_band, prev_supertrend].min
            trend[i] = candle.close <= supertrend[i] ? :bearish : :bullish
          else
            supertrend[i] = [lower_band, prev_supertrend].max
            trend[i] = candle.close >= supertrend[i] ? :bullish : :bearish
          end
        end

        supertrend_values[i] = supertrend[i]
      end

      supertrend_values
    end

    private

    def calculate_atr
      tr = []
      atr = []

      series.each_with_index do |candle, i|
        if i.zero?
          tr[i] = candle.high - candle.low
        else
          prev_close = series[i - 1].close
          tr[i] = [
            candle.high - candle.low,
            (candle.high - prev_close).abs,
            (candle.low - prev_close).abs
          ].max
        end
      end

      # Simple Moving Average for ATR
      (0...series.size).each do |i|
        atr[i] = if i < period
                   nil
                 else
                   tr[(i - period + 1)..i].compact.sum / period
                 end
      end

      atr
    end
  end
end
