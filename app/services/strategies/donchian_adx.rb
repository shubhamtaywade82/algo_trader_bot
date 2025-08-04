module Strategies
  class DonchianAdx < BaseIndicatorStrategy
    def signal?
      close = instrument.candles.closes.last
      donchians = instrument.donchian_channel
      adx = instrument.adx

      return :buy_ce if close > donchians.first.upper_bound && adx > 25

      :buy_pe if close < donchians.first.lower_bound && adx > 25
    end

    def confidence_score = 70
    def reason_text = "Donchian/ADX: Close=#{instrument.candles.closes.last}, Donchian=#{instrument.donchian_channel.first.inspect}, ADX=#{instrument.adx}"
  end
end

