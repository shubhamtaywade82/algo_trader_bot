module Strategies
  class PriceActionStrategy < ApplicationService
    def initialize(instrument, interval: '5')
      @instrument = instrument
      @interval = interval
      @series = CandleSeries.new(symbol: instrument.symbol_name, interval:)
      raw = instrument.intraday_ohlc(interval: interval)
      @series.load_from_raw(raw)
    end

    def signal?
      # basic setup
      @last = @series.candles.last
      @prev = @series.candles[-2]
      @third = @series.candles[-3]

      bullish_pinbar? || bearish_engulfing? || breakout_candle?
    end

    private

    def bullish_pinbar?
      body = (@last.close - @last.open).abs
      lower_wick = @last.open - @last.low if @last.bullish?
      lower_wick = @last.close - @last.low if @last.bearish?

      lower_wick && lower_wick > body * 2 && @last.close > @last.open
    end

    def bearish_engulfing?
      @prev.bullish? &&
        @last.bearish? &&
        @last.open > @prev.close &&
        @last.close < @prev.open
    end

    def breakout_candle?
      highs = @series.candles[-5..-2].map(&:high)
      @last.high > highs.max && @last.close > highs.max
    end
  end
end