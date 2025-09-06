# frozen_string_literal: true

# Trend following strategy for longer-term positions
# Uses multi-timeframe analysis with Holy Grail and Supertrend
class Strategy::TrendFollower < Strategy::Base
  attribute :trend_timeframe, :string, default: '5m'
  attribute :entry_timeframe, :string, default: '1m'
  attribute :trend_strength_threshold, :decimal, default: 0.7
  attribute :min_confidence, :decimal, default: 0.6
  attribute :max_trade_duration, :integer, default: 120 # minutes
  attribute :trend_confirmation_periods, :integer, default: 3

  def initialize(attributes = {})
    super(attributes.merge(name: 'TrendFollower'))
  end

  def execute(instrument, market_data)
    return nil unless valid_for_trading?(instrument, market_data)

    trend_signal = analyze_trend(instrument, market_data)
    return nil unless trend_signal

    entry_signal = analyze_entry(instrument, market_data)
    return nil unless entry_signal && entry_signal[:side] == trend_signal[:side]

    build_trade_plan(
      instrument,
      trend_signal[:side],
      market_data[:ltp],
      market_data,
      confidence: trend_signal[:confidence],
      stop_loss_percentage: trend_signal[:stop_loss_percentage] || 0.03,
      risk_reward_ratio: trend_signal[:risk_reward_ratio] || 2.5
    )
  end

  def should_exit?(position, market_data)
    time_based_exit?(position, max_trade_duration.minutes) ||
      profit_target_hit?(position, market_data[:ltp]) ||
      stop_loss_hit?(position, market_data[:ltp]) ||
      trend_reversal?(position, market_data) ||
      trend_weakening?(position, market_data)
  end

  private

  def market_conditions_valid?(market_data)
    super(market_data) &&
      market_data[:trend_strength] >= trend_strength_threshold &&
      market_data[:volume] >= 500 &&
      market_data[:trend_candles].present? &&
      market_data[:trend_candles].length >= 20 &&
      market_data[:entry_candles].present? &&
      market_data[:entry_candles].length >= 10
  end

  def analyze_trend(instrument, market_data)
    trend_candles = market_data[:trend_candles]
    return nil unless trend_candles&.length >= 20

    holy_grail = Indicators::HolyGrail.new(trend_candles)
    return nil unless holy_grail.valid?

    # Check for trend confirmation over multiple periods
    trend_confirmed = check_trend_confirmation(trend_candles, holy_grail)
    return nil unless trend_confirmed

    if holy_grail.bullish?
      build_trend_signal('BUY', holy_grail, market_data)
    elsif holy_grail.bearish?
      build_trend_signal('SELL', holy_grail, market_data)
    end
  end

  def analyze_entry(instrument, market_data)
    entry_candles = market_data[:entry_candles]
    return nil unless entry_candles&.length >= 10

    supertrend = Indicators::Supertrend.new(entry_candles)
    return nil unless supertrend.valid?

    if supertrend.bullish?
      build_entry_signal('BUY', supertrend, market_data)
    elsif supertrend.bearish?
      build_entry_signal('SELL', supertrend, market_data)
    end
  end

  def check_trend_confirmation(candles, holy_grail)
    return false unless candles.length >= trend_confirmation_periods

    # Check if trend has been consistent over confirmation periods
    recent_candles = candles.last(trend_confirmation_periods)
    trend_direction = holy_grail.bullish? ? 'BUY' : 'SELL'

    recent_candles.each_cons(2).all? do |prev, curr|
      case trend_direction
      when 'BUY'
        curr[:close] >= prev[:close]
      when 'SELL'
        curr[:close] <= prev[:close]
      end
    end
  end

  def build_trend_signal(side, holy_grail, market_data)
    confidence = calculate_trend_confidence(holy_grail, market_data)
    return nil if confidence < min_confidence

    {
      side: side,
      confidence: confidence,
      stop_loss_percentage: calculate_trend_stop_loss_percentage(confidence),
      risk_reward_ratio: calculate_trend_risk_reward_ratio(confidence),
      trend_strength: holy_grail.strength,
      timeframe: trend_timeframe
    }
  end

  def build_entry_signal(side, supertrend, market_data)
    confidence = calculate_entry_confidence(supertrend, market_data)
    return nil if confidence < min_confidence

    {
      side: side,
      confidence: confidence,
      entry_strength: supertrend.strength,
      timeframe: entry_timeframe
    }
  end

  def calculate_trend_confidence(holy_grail, market_data)
    # Base confidence from trend strength
    trend_confidence = holy_grail.strength

    # Adjust for market conditions
    volume_factor = calculate_volume_factor(market_data)
    volatility_factor = calculate_volatility_factor(market_data)
    momentum_factor = calculate_momentum_factor(market_data)

    # Weighted confidence calculation
    (trend_confidence * 0.5 +
     volume_factor * 0.2 +
     volatility_factor * 0.15 +
     momentum_factor * 0.15).round(3)
  end

  def calculate_entry_confidence(supertrend, market_data)
    # Entry confidence based on supertrend strength
    entry_confidence = supertrend.strength

    # Adjust for entry timing
    timing_factor = calculate_timing_factor(market_data)
    spread_factor = calculate_spread_factor(market_data)

    (entry_confidence * 0.7 + timing_factor * 0.2 + spread_factor * 0.1).round(3)
  end

  def calculate_volume_factor(market_data)
    return 0.5 unless market_data[:volume].present?

    # Prefer higher volume for trend following
    case market_data[:volume]
    when 0..100 then 0.3
    when 100..500 then 0.6
    when 500..1000 then 0.8
    when 1000..5000 then 1.0
    else 0.9 # Very high volume might indicate volatility
    end
  end

  def calculate_volatility_factor(market_data)
    return 0.5 unless market_data[:candles]&.length >= 10

    volatility = calculate_market_volatility(market_data)
    # Prefer moderate to high volatility for trend following
    case volatility
    when 0.0..0.2 then 0.4  # Too low
    when 0.2..0.5 then 0.8  # Good
    when 0.5..0.8 then 1.0  # Ideal
    when 0.8..1.0 then 0.7  # High but acceptable
    else 0.5
    end
  end

  def calculate_momentum_factor(market_data)
    return 0.5 unless market_data[:candles]&.length >= 5

    recent_candles = market_data[:candles].last(5)
    closes = recent_candles.map { |c| c[:close] }
    return 0.5 if closes.length < 2

    # Calculate momentum
    momentum = (closes.last - closes.first) / closes.first
    [momentum.abs * 2, 1.0].min
  end

  def calculate_timing_factor(market_data)
    # Check if we're entering at a good time
    return 0.5 unless market_data[:candles]&.length >= 3

    recent_candles = market_data[:candles].last(3)
    closes = recent_candles.map { |c| c[:close] }

    # Check for pullback or continuation
    if closes.last > closes.first
      0.8 # Continuation
    elsif closes.last < closes.first
      0.6 # Pullback
    else
      0.5 # Sideways
    end
  end

  def calculate_spread_factor(market_data)
    return 0.5 unless market_data[:bid_ask_spread].present?

    spread = market_data[:bid_ask_spread]
    case spread
    when 0.0..0.05 then 1.0
    when 0.05..0.1 then 0.8
    when 0.1..0.2 then 0.6
    else 0.4
    end
  end

  def calculate_trend_stop_loss_percentage(confidence)
    # Wider stops for trend following
    base_stop = 0.03
    confidence_adjustment = (1.0 - confidence) * 0.01
    [base_stop - confidence_adjustment, 0.02].max
  end

  def calculate_trend_risk_reward_ratio(confidence)
    # Better R:R for trend following
    base_ratio = 2.5
    confidence_adjustment = confidence * 0.5
    base_ratio + confidence_adjustment
  end

  def calculate_market_volatility(market_data)
    return 0.5 unless market_data[:candles]&.length >= 10

    prices = market_data[:candles].last(10).map { |c| c[:close] }
    return 0.5 if prices.length < 2

    returns = prices.each_cons(2).map { |a, b| (b - a) / a }
    volatility = Math.sqrt(returns.map { |r| r**2 }.sum / returns.length)
    [volatility * 100, 1.0].min
  end

  def trend_reversal?(position, market_data)
    return false unless market_data[:trend_candles]&.length >= 10

    # Check if trend has reversed on higher timeframe
    recent_trend_candles = market_data[:trend_candles].last(5)
    return false unless recent_trend_candles.length >= 3

    holy_grail = Indicators::HolyGrail.new(recent_trend_candles)
    return false unless holy_grail.valid?

    current_trend = holy_grail.bullish? ? 'BUY' : 'SELL'
    current_trend != position.side
  end

  def trend_weakening?(position, market_data)
    return false unless market_data[:trend_candles]&.length >= 10

    # Check if trend strength is weakening
    recent_candles = market_data[:trend_candles].last(5)
    holy_grail = Indicators::HolyGrail.new(recent_candles)
    return false unless holy_grail.valid?

    # Exit if trend strength drops below threshold
    holy_grail.strength < (trend_strength_threshold * 0.7)
  end
end
