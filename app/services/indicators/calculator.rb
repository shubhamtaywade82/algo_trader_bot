module Indicators
  class Calculator
    def initialize(series)
      @series = series
    end

    def rsi(period = 14)
      RubyTechnicalAnalysis::RelativeStrengthIndex.new(series: @series.closes, period:).call
    end

    def macd
      macd = RubyTechnicalAnalysis::MACD.new(series: @series.closes)
      macd.call
    end

    def adx(period = 14)
      hlc = @series.each.map { |c| [c.high, c.low, c.close] }
      RubyTechnicalAnalysis::ADX.new(series: hlc, period:).call
    end

    def signal?
      rsi_val = rsi.last
      adx_val = adx.last
      rsi_val < 30 && adx_val > 20
    end
  end
end