# app/services/indicators/intrinio_wrapper.rb
module Indicators
  class IntrinioWrapper
    SUPPORTED = TechnicalAnalysis::Indicator.names.map(&:to_s)
    attr_reader :data

    def initialize(data)
      @data = data
    end

    # example: RSI
    def rsi(period: 14)
      vals = TechnicalAnalysis::Rsi.calculate(data,
                                              period: period, price_key: :close)
      vals.map(&:value)
    end

    def adx(period: 14)
      vals = TechnicalAnalysis::Adx.calculate(data, period: period, price_key: :close)
      vals.map(&:adx)
    end

    def macd(fast: 12, slow: 26, signal: 9)
      TechnicalAnalysis::Macd.calculate(data,
                                        fast_period: fast, slow_period: slow, signal_period: signal, price_key: :close)
    end

    def obv
      TechnicalAnalysis::Obv.calculate(data, price_key: :close, volume_key: :volume)
    end

    # .. auto-generate other wrappers via meta-programming if you like
    def self.supports?(name)
      SUPPORTED.include?(name.to_s)
    end
  rescue TechnicalAnalysis::ValidationError => e
    Rails.logger.warn("[IntrinioWrapper] #{e.class}: #{e.message}")
    []
  end
end
