module Strategies
  class SmartMoneyStrategy
    def initialize(instrument)
      @instrument = instrument
      raw = instrument.intraday_ohlc(interval: '5')
      @series = CandleSeries.new(symbol: instrument.symbol_name)
      @series.load_from_raw(raw)
    end

    def signal?
      fvg     = Indicators::FairValueGap.new(@series).detect.last
      blocks  = Indicators::OrderBlock.new(@series).bullish_order_blocks.last
      bos     = Indicators::Structure.new(@series).break_of_structure.last

      return false unless bos && fvg && blocks

      # Apply filters (e.g., direction match)
      bos[:direction] == :up && blocks[:low] > fvg[:from]
    end

    def analysis_result
      {
        symbol: @instrument.symbol_name,
        interval: @series.interval,
        structure: Indicators::Structure.new(@series).summary,
        order_blocks: Indicators::OrderBlock.new(@series).summary,
        fair_value_gaps: Indicators::FairValueGap.new(@series).summary,
        current_price: @series.closes.last,
        signal: signal? ? :long_entry : :hold
      }
    end
  end
end
