module Strategies
  class LiquidityGrabStrategy < ApplicationService
    def initialize(instrument)
      @instrument = instrument
      raw = instrument.intraday_ohlc(interval: '5')
      @series = CandleSeries.new(symbol: instrument.symbol_name)
      @series.load_from_raw(raw)
    end

    def signal?
      grab_up = @series.liquidity_grab_up?
      grab_down = @series.liquidity_grab_down?

      return :short if grab_up
      return :long  if grab_down

      nil
    end
  end
end