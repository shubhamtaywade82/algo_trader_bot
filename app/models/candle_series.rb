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
        ts: Time.zone.parse(row['timestamp'].to_s),
        open: row['open'], high: row['high'],
        low: row['low'], close: row['close'],
        volume: row['volume']
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
        timestamp: Time.zone.parse(resp['timestamp'][i].to_s),
        volume: resp['volume'][i].to_i
      }
    end
  end

  def closes = candles.map(&:close)
  def highs  = candles.map(&:high)
  def lows   = candles.map(&:low)
end