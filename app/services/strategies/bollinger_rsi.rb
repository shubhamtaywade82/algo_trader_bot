module Strategies
  class BollingerRsi < BaseIndicatorStrategy
    def signal?
      rsi = instrument.rsi
      close = instrument.candles.closes.last
      bands = instrument.bollinger_bands

      pp "RSI: #{rsi}, Close: #{close}, Bands: #{bands.inspect}"
      return :buy_ce if close > bands[:upper] && rsi < 70

      :buy_pe if close < bands[:lower] && rsi > 30
    end

    def confidence_score = 65
    def reason_text = "BB/RSI: Close=#{series.closes.last}, RSI=#{series.rsi}, Bands=#{series.bollinger_bands.inspect}"
  end
end

