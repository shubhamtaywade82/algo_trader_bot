module InstrumentHelpers
  extend ActiveSupport::Concern
  include CandleExtension

  included do
    # Enums common to Instrument and Derivative
    enum :exchange, { nse: 'NSE', bse: 'BSE', mcx: 'MCX' }
    enum :segment, { index: 'I', equity: 'E', currency: 'C', derivatives: 'D', commodity: 'M' }, prefix: true
    enum :instrument_code, {
      index: 'INDEX',
      futures_index: 'FUTIDX',
      options_index: 'OPTIDX',
      equity: 'EQUITY',
      futures_stock: 'FUTSTK',
      options_stock: 'OPTSTK',
      futures_currency: 'FUTCUR',
      options_currency: 'OPTCUR',
      futures_commodity: 'FUTCOM',
      options_commodity: 'OPTFUT'
    }, prefix: true

    scope :nse, -> { where(exchange: 'NSE') }
    scope :bse, -> { where(exchange: 'BSE') }

    # Validations for enums can also go here, if common
  end

  # Shared instance methods for market data fetching and helpers
  def ltp
    fetch_ltp_from_api
  rescue StandardError => e
    Rails.logger.error("Failed to fetch LTP for #{self.class.name} #{security_id}: #{e.message}")
    nil
  end

  def quote_ltp
    quote = quotes.order(tick_time: :desc).first
    return nil unless quote

    quote.ltp.to_f
  rescue StandardError => e
    Rails.logger.error("Failed to fetch latest quote LTP for #{self.class.name} #{security_id}: #{e.message}")
    nil
  end

  def fetch_ltp_from_api
    response = DhanHQ::Models::MarketFeed.ltp(exch_segment_enum)
    response.dig('data', exchange_segment, security_id.to_s, 'last_price') if response['status'] == 'success'
  rescue StandardError => e
    Rails.logger.error("Failed to fetch LTP from API for #{self.class.name} #{security_id}: #{e.message}")
    nil
  end

  def subscribe_params
    { ExchangeSegment: exchange_segment, SecurityId: security_id.to_s }
  end

  def ws_get
    Live::TickCache.get(exchange_segment, security_id.to_s)
  end

  def ws_ltp
    ws_get&.dig(:ltp)
  end

  def ohlc
    response = DhanHQ::Models::MarketFeed.ohlc(exch_segment_enum)
    response['status'] == 'success' ? response.dig('data', exchange_segment, security_id.to_s) : nil
  rescue StandardError => e
    Rails.logger.error("Failed to fetch OHLC for #{self.class.name} #{security_id}: #{e.message}")
    nil
  end

  def historical_ohlc(from_date: nil, to_date: nil, oi: false)
    DhanHQ::Models::HistoricalData.daily(
      securityId: security_id,
      exchangeSegment: exchange_segment,
      instrument: instrument_type,
      oi: oi,
      fromDate: from_date || (Time.zone.today - 365).to_s,
      toDate: to_date || (Time.zone.today - 1).to_s,
      expiryCode: 0
    )
  rescue StandardError => e
    Rails.logger.error("Failed to fetch Historical OHLC for #{self.class.name} #{security_id}: #{e.message}")
    nil
  end

  def intraday_ohlc(interval: '5', oi: false, from_date: nil, to_date: nil, days: 90)
    to_date ||= MarketCalendar.today_or_last_trading_day.to_s
    from_date ||= (Date.parse(to_date) - days).to_s # fetch last 5 sessions by default

    DhanHQ::Models::HistoricalData.intraday(
      security_id: security_id,
      exchange_segment: exchange_segment,
      instrument: instrument_type,
      interval: interval,
      oi: oi,
      from_date: from_date || (Time.zone.today - days).to_s,
      to_date: to_date || (Time.zone.today - 1).to_s
    )
  rescue StandardError => e
    Rails.logger.error("Failed to fetch Intraday OHLC for #{self.class.name} #{security_id}: #{e.message}")
    nil
  end

  def depth
    response = DhanHQ::Models::MarketFeed.quote(exch_segment_enum)
    response['status'] == 'success' ? response.dig('data', exchange_segment, security_id.to_s) : nil
  rescue StandardError => e
    Rails.logger.error("Failed to fetch Depth for #{self.class.name} #{security_id}: #{e.message}")
    nil
  end

  # Helper method: dynamic exchange_segment string for API calls
  def exchange_segment
    case [exchange.to_sym, segment.to_sym]
    when %i[nse index], %i[bse index] then 'IDX_I'
    when %i[nse equity] then 'NSE_EQ'
    when %i[bse equity] then 'BSE_EQ'
    when %i[nse derivatives] then 'NSE_FNO'
    when %i[bse derivatives] then 'BSE_FNO'
    when %i[nse currency] then 'NSE_CURRENCY'
    when %i[bse currency] then 'BSE_CURRENCY'
    when %i[mcx commodity] then 'MCX_COMM'
    else
      raise "Unsupported exchange and segment combination: #{exchange}, #{segment}"
    end
  end

  private

  def exch_segment_enum
    { exchange_segment => [security_id.to_i] }
  end

  def numeric_value?(value)
    value.is_a?(Numeric) || value.to_s.match?(/\A-?\d+(\.\d+)?\z/)
  end
end