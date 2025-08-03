# Extend Instrument with candle series integration
module CandleExtension
  extend ActiveSupport::Concern

  included do
    def candles(interval: '5')
      raw_data = intraday_ohlc(interval: interval)
      return nil unless raw_data

      series = CandleSeries.new(symbol: symbol_name, interval: interval)
      series.load_from_raw(raw_data)
      series
    end

    def candle_series(interval: '5')
      candles(interval: interval)
    end

    def rsi(period = 14, interval: '5')
      cs = candles(interval: interval)
      cs&.rsi(period)
    end

    def macd(fast_period = 12, slow_period = 26, signal_period = 9, interval: '5')
      cs = candles(interval: interval)
      macd_result = cs&.macd(fast_period, slow_period, signal_period)
      return nil unless macd_result

      {
        macd: macd_result[0],
        signal: macd_result[1],
        histogram: macd_result[2]
      }
    end

    def adx(period = 14, interval: '5')
      cs = candles(interval: interval)
      closes = cs&.closes
      highs  = cs&.highs
      lows   = cs&.lows
      return nil unless closes && highs && lows

      hlc = cs.candles.each_with_index.map do |c, _i|
        {
          date_time: Time.zone.at(c.timestamp || 0), # <- NEW
          high: c.high,
          low: c.low,
          close: c.close
        }
      end

      ta_adx = TechnicalAnalysis::Adx.calculate(hlc, period: period).first
      ta_adx&.adx
    end

    def supertrend_signal(interval: '5')
      cs = candles(interval: interval)
      cs&.supertrend_signal

    def liquidity_grab_up?(interval: '5')
      cs = candles(interval: interval)
      cs&.liquidity_grab_up?
    end

    def liquidity_grab_down?(interval: '5')
      cs = candles(interval: interval)
      cs&.liquidity_grab_down?
    end

    def candle_series(interval: '5')
      candles(interval: interval)
    end
  end
end
