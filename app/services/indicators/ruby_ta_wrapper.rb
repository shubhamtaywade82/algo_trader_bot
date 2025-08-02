# app/services/indicators/ruby_ta_wrapper.rb
module Indicators
  class RubyTAWrapper
    SUPPORTED = %w[
      rsi macd stochastic_intraday momentum_index chaikin_money_flow
      bollinger_bands pivot_points mass_index qstick rate_of_change
      wilders_smoothing volume_oscillator williams_r price_channel
    ]
    attr_reader :series

    def initialize(series) = @series = series

    # e.g.
    def rsi(period: 14)
      t = RubyTechnicalAnalysis::RelativeStrengthIndex.new(
               series: series.closes, period: period
             )
      t.valid? ? t.call : []
    end

    def macd(fast: 12, slow: 26, signal: 9)
      t = RubyTechnicalAnalysis::MACD.new(series: series.closes,
                                          fast_period: fast, slow_period: slow, signal_period: signal)
      t.valid? ? t.call : []
    end

    # ... same pattern for other SUPPORTED indicators

    def self.supports?(name)
      SUPPORTED.include?(name.to_s)
    end
  end
end
