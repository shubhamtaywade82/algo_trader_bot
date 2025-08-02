module Strategies
  class BasicTrendStrategy < ApplicationService
    def initialize(instrument)
      @instrument = instrument
      raw_data = instrument.intraday_ohlc(interval: '5')
      @series = CandleSeries.new(symbol: instrument.symbol_name)
      @series.load_from_raw(raw_data)
    end

    def call
      calc = Indicators::Calculator.new(@series)
      return :buy_ce if calc.signal?

      :hold
    end
  end
end