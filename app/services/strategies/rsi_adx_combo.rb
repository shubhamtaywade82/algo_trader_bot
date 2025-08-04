module Strategies
  class RsiAdxCombo < BaseIndicatorStrategy
    def signal?
      rsi = instrument.rsi
      adx = instrument.adx

      return :buy_ce if rsi > 30 && adx > 20

      :buy_pe if rsi < 70 && adx > 20
    end

    def confidence_score = 70

    def reason_text
      "RSI/ADX Combo: RSI=#{instrument.rsi.round(2)}, ADX=#{instrument.adx.round(2)}"
    end
  end
end

