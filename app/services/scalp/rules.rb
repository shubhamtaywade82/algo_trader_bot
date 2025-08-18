module Scalp
  class Rules
    # candles => your CandleSeries for 1m
    # Expect: supertrend(direction: :up|:down), rsi(14), adx(14)
    def self.entry_signal(symbol, candles)
      st  = candles.supertrend(factor: 2.0, period: 10)
      rsi = candles.rsi(14).last
      adx = candles.adx(14).last
      dir = st.direction # :up or :down at last bar

      return nil unless adx && adx > 25

      if dir == :up && rsi && rsi > 50
        OpenStruct.new(direction: :bullish)
      elsif dir == :down && rsi && rsi < 50
        OpenStruct.new(direction: :bearish)
      end
    end
  end
end