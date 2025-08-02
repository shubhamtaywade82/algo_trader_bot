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

  def closes = candles.map(&:close)
  def highs  = candles.map(&:high)
  def lows   = candles.map(&:low)

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
end