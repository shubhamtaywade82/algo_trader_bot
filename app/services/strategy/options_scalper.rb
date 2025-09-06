# frozen_string_literal: true

# Options scalping strategy for quick intraday trades
# Uses Holy Grail and Supertrend indicators for signal generation
class Strategy::OptionsScalper < Strategy::Base
  attribute :timeframe, :string, default: '1m'
  attribute :min_volume, :integer, default: 1000
  attribute :max_oi_ratio, :decimal, default: 0.8
  attribute :max_bid_ask_spread, :decimal, default: 0.1
  attribute :min_confidence, :decimal, default: 0.7
  attribute :max_trade_duration, :integer, default: 30 # minutes

  def initialize(attributes = {})
    super(attributes.merge(name: 'OptionsScalper'))
  end

  def execute(instrument, market_data)
    return nil unless valid_for_trading?(instrument, market_data)

    signal = analyze_market(instrument, market_data)
    return nil unless signal

    build_trade_plan(
      instrument,
      signal[:side],
      market_data[:ltp],
      market_data,
      confidence: signal[:confidence],
      stop_loss_percentage: signal[:stop_loss_percentage] || 0.02,
      risk_reward_ratio: signal[:risk_reward_ratio] || 2.0
    )
  end

  def should_exit?(position, market_data)
    time_based_exit?(position, max_trade_duration.minutes) ||
      profit_target_hit?(position, market_data[:ltp]) ||
      stop_loss_hit?(position, market_data[:ltp]) ||
      trend_reversal?(position, market_data)
  end

  private

  def market_conditions_valid?(market_data)
    super(market_data) &&
      market_data[:volume] >= min_volume &&
      market_data[:oi_ratio] <= max_oi_ratio &&
      market_data[:bid_ask_spread] <= max_bid_ask_spread &&
      market_data[:candles].present? &&
      market_data[:candles].length >= 20
  end

  def analyze_market(instrument, market_data)
    candles = market_data[:candles]
    return nil unless candles&.length >= 20

    # Use Holy Grail indicator for trend analysis
    holy_grail = Indicators::HolyGrail.new(candles)
    return nil unless holy_grail.valid?

    # Use Supertrend for confirmation
    supertrend = Indicators::Supertrend.new(candles)
    return nil unless supertrend.valid?

    # Check for confluence
    if holy_grail.bullish? && supertrend.bullish?
      build_signal('BUY', holy_grail, supertrend, market_data)
    elsif holy_grail.bearish? && supertrend.bearish?
      build_signal('SELL', holy_grail, supertrend, market_data)
    end
  end

  def build_signal(side, holy_grail, supertrend, market_data)
    confidence = calculate_confidence(holy_grail, supertrend, market_data)
    return nil if confidence < min_confidence

    {
      side: side,
      confidence: confidence,
      stop_loss_percentage: calculate_stop_loss_percentage(confidence),
      risk_reward_ratio: calculate_risk_reward_ratio(confidence),
      holy_grail_strength: holy_grail.strength,
      supertrend_strength: supertrend.strength,
      market_volatility: calculate_market_volatility(market_data)
    }
  end

  def calculate_confidence(holy_grail, supertrend, market_data)
    # Base confidence from indicators
    indicator_confidence = (holy_grail.strength + supertrend.strength) / 2.0

    # Adjust for market conditions
    volume_factor = [market_data[:volume] / 1000.0, 1.0].min
    spread_factor = [1.0 - (market_data[:bid_ask_spread] / 0.1), 0.5].max
    volatility_factor = calculate_volatility_factor(market_data)

    # Weighted confidence calculation
    (indicator_confidence * 0.4 +
     volume_factor * 0.2 +
     spread_factor * 0.2 +
     volatility_factor * 0.2).round(3)
  end

  def calculate_stop_loss_percentage(confidence)
    # Tighter stops for higher confidence
    base_stop = 0.02
    confidence_adjustment = (1.0 - confidence) * 0.01
    [base_stop - confidence_adjustment, 0.01].max
  end

  def calculate_risk_reward_ratio(confidence)
    # Better R:R for higher confidence
    base_ratio = 2.0
    confidence_adjustment = confidence * 0.5
    base_ratio + confidence_adjustment
  end

  def calculate_market_volatility(market_data)
    return 0.5 unless market_data[:candles]&.length >= 10

    prices = market_data[:candles].last(10).map { |c| c[:close] }
    return 0.5 if prices.length < 2

    returns = prices.each_cons(2).map { |a, b| (b - a) / a }
    volatility = Math.sqrt(returns.map { |r| r**2 }.sum / returns.length)
    [volatility * 100, 1.0].min # Cap at 1.0
  end

  def calculate_volatility_factor(market_data)
    volatility = calculate_market_volatility(market_data)
    # Prefer moderate volatility for scalping
    case volatility
    when 0.0..0.3 then 0.8  # Too low volatility
    when 0.3..0.7 then 1.0  # Ideal range
    when 0.7..1.0 then 0.6  # Too high volatility
    else 0.5
    end
  end

  def trend_reversal?(position, market_data)
    return false unless market_data[:candles]&.length >= 10

    # Quick trend check using recent candles
    recent_candles = market_data[:candles].last(5)
    return false unless recent_candles.length >= 3

    # Simple trend detection
    closes = recent_candles.map { |c| c[:close] }
    trend_direction = closes.last > closes.first ? 'BUY' : 'SELL'

    trend_direction != position.side
  end

  def calculate_current_pnl(position, current_price)
    super(position, current_price)
  end
end
