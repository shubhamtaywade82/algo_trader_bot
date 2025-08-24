class CandleSeries
  include Enumerable

  attr_reader :symbol, :interval, :candles

  def initialize(symbol:, interval: '5')
    @symbol = symbol
    @interval = interval
    @candles = []
  end

  def each(&) = candles.each(&)
  def add_candle(candle) = candles << candle

  def load_from_raw(response)
    normalise_candles(response).each do |row|
      @candles << Candle.new(
        ts: Time.zone.parse(row[:timestamp].to_s),
        open: row[:open], high: row[:high],
        low: row[:low], close: row[:close],
        volume: row[:volume]
      )
    end
  end

  def normalise_candles(resp)
    return [] if resp.blank?

    return resp.map { |c| slice_candle(c) } if resp.is_a?(Array)

    raise "Unexpected candle format: #{resp.class}" unless resp.is_a?(Hash) && resp['high'].is_a?(Array)

    size = resp['high'].size
    (0...size).map do |i|
      {
        open: resp['open'][i].to_f,
        close: resp['close'][i].to_f,
        high: resp['high'][i].to_f,
        low: resp['low'][i].to_f,
        timestamp: Time.zone.at(resp['timestamp'][i]),
        volume: resp['volume'][i].to_i
      }
    end
  end

  private

  # Normalises a single candle entry which may be provided either as a Hash
  # with symbol/string keys or as an Array in the order:
  # [timestamp, open, high, low, close, volume].
  def slice_candle(candle)
    if candle.is_a?(Hash)
      {
        open: candle[:open] || candle['open'],
        close: candle[:close] || candle['close'],
        high: candle[:high] || candle['high'],
        low: candle[:low] || candle['low'],
        timestamp: candle[:timestamp] || candle['timestamp'],
        volume: candle[:volume] || candle['volume'] || 0
      }
    elsif candle.respond_to?(:[]) && candle.size >= 6
      {
        timestamp: candle[0],
        open: candle[1],
        high: candle[2],
        low: candle[3],
        close: candle[4],
        volume: candle[5]
      }
    else
      raise "Unexpected candle format: #{candle.inspect}"
    end
  end

  def opens  = candles.map(&:open)
  def closes = candles.map(&:close)
  def highs  = candles.map(&:high)
  def lows   = candles.map(&:low)

  def hlc
    candles.each_with_index.map do |c, _i|
      {
        date_time: Time.zone.at(c.timestamp || 0),
        high: c.high,
        low: c.low,
        close: c.close
      }
    end
  end

  def atr(period = 14)
    TechnicalAnalysis::Atr.calculate(hlc, period: period).first.atr
  end

  def swing_high?(index, lookback = 2)
    return false if index < lookback || index + lookback >= candles.size

    current = candles[index].high
    left = candles[(index - lookback)...index].map(&:high)
    right = candles[(index + 1)..(index + lookback)].map(&:high)
    current > left.max && current > right.max
  end

  def swing_low?(index, lookback = 2)
    return false if index < lookback || index + lookback >= candles.size

    current = candles[index].low
    left = candles[(index - lookback)...index].map(&:low)
    right = candles[(index + 1)..(index + lookback)].map(&:low)
    current < left.min && current < right.min
  end

  def recent_highs(n = 20)
    candles.last(n).map(&:high)
  end

  def recent_lows(n = 20)
    candles.last(n).map(&:low)
  end

  def previous_swing_high
    recent_highs.sort[-2] # 2nd highest
  end

  def previous_swing_low
    recent_lows.sort[1]   # 2nd lowest
  end

  def liquidity_grab_up?(lookback: 20)
    high_now = candles.last.high
    high_prev = previous_swing_high

    high_now > high_prev &&
      candles.last.close < high_prev && # Rejection after breakout
      candles.last.bearish?
  end

  def liquidity_grab_down?(lookback: 20)
    low_now = candles.last.low
    low_prev = previous_swing_low

    low_now < low_prev &&
      candles.last.close > low_prev && # Rejection after breakdown
      candles.last.bullish?
  end

  def rsi(period = 14)
    RubyTechnicalAnalysis::RelativeStrengthIndex.new(series: closes, period: period).call
  end

  def moving_average(period = 20)
    RubyTechnicalAnalysis::MovingAverages.new(series: closes, period: period)
  end

  def sma(period = 20)
    moving_average(period).sma
  end

  def ema(period = 20)
    moving_average(period).ema
  end

  def macd(fast_period = 12, slow_period = 26, signal_period = 9)
    macd = RubyTechnicalAnalysis::Macd.new(series: closes, fast_period: fast_period, slow_period: slow_period, signal_period: signal_period)
    macd.call
  end

  def rate_of_change(period = 5)
    closes = self.closes
    return nil if closes.size < period + 1

    # ((current_close - close_n_periods_ago) / close_n_periods_ago) * 100
    roc_series = []
    closes.each_with_index do |price, idx|
      if idx < period
        roc_series << nil # not enough data for these initial points
      else
        previous_price = closes[idx - period]
        roc_series << (((price - previous_price) / previous_price.to_f) * 100.0)
      end
    end
    roc_series
  end

  def supertrend_signal
    trend_line = Indicators::Supertrend.new(series: self).call
    return nil if trend_line.empty?

    latest_close = closes.last
    latest_trend = trend_line.last

    return :long_entry if latest_close > latest_trend

    :short_entry if latest_close < latest_trend
  end

  def inside_bar?(i)
    return false if i < 1

    curr = @candles[i]
    prev = @candles[i - 1]
    curr.high < prev.high && curr.low > prev.low
  end

  def bollinger_bands(period: 20)
    return nil if candles.size < period

    bb = RubyTechnicalAnalysis::BollingerBands.new(
      series: closes,
      period: period
    ).call

    { upper: bb[0], lower: bb[1], middle: bb[2] }
  end

  def donchian_channel(period: 20)
    return nil if candles.size < period

    dc = candles.each_with_index.map do |c, _i|
      {
        date_time: Time.zone.at(c.timestamp || 0),
        value: c.close
      }
    end
    TechnicalAnalysis::Dc.calculate(dc, period: period)
  end
end