module Strategies
  class BaseIndicatorStrategy
    attr_reader :instrument, :series, :interval

    def initialize(instrument, series: nil)
      @instrument = instrument
      @series = series || instrument.candles('5')
    end

    def initialize(instrument, series: nil, interval: '5')
      @instrument = instrument
      @interval = interval
      @series = series || instrument.candles(interval)
    end

    def series
      @series ||= instrument.candles(interval)
    end

    def candles
      @candles ||= series.candles
    end

    def closes
      @closes ||= candles.map(&:close)
    end

    def highs
      @highs ||= candles.map(&:high)
    end

    def lows
      @lows ||= candles.map(&:low)
    end

    def opens
      @opens ||= candles.map(&:open)
    end

    def volumes
      @volumes ||= candles.map(&:volume)
    end

    def last_candle
      @last_candle ||= candles.last
    end

    def signal?
      raise NotImplementedError, "#{self.class.name} must implement #signal?"
    end

    def signal_details
      result = signal?
      return nil unless result

      {
        signal: result,
        confidence: confidence_score,
        reason: reason_text
      }
    end
  end
end