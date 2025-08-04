module Strategies
  class VwapRsi < BaseIndicatorStrategy
    def signal?
      close = instrument.candles.closes.last
      vwap = instrument.vwap
      rsi = instrument.rsi

      return :buy_ce if close > vwap && rsi > 40

      :buy_pe if close < vwap && rsi < 60
    end

    def confidence_score = 60
    def reason_text = "VWAP/RSI: Close=#{series.closes.last}, VWAP=#{series.vwap}, RSI=#{series.rsi.last}"
  end
end

