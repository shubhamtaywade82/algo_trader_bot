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
      hlc = @series.candles.each_with_index.map do |c, _i|
        {
          date_time: Time.zone.at(c.timestamp || 0), # <- NEW
          high: c.high,
          low: c.low,
          close: c.close
        }
      end
      TechnicalAnalysis::Adx.calculate(hlc, period:)
    end

    def signal?
      rsi_val = rsi
      adx_val = adx.last.adx
      rsi_val < 30 && adx_val > 20
    end
  end
end