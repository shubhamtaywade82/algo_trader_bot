# frozen_string_literal: true

# Breakout scalping strategy for quick trades on price breakouts
# Uses support/resistance levels and volume confirmation
class Strategy::BreakoutScalper < Strategy::Base
  attribute :lookback_periods, :integer, default: 20
  attribute :breakout_threshold, :decimal, default: 0.005 # 0.5%
  attribute :volume_multiplier, :decimal, default: 1.5
  attribute :min_confidence, :decimal, default: 0.65
  attribute :max_trade_duration, :integer, default: 15 # minutes
  attribute :consolidation_periods, :integer, default: 5

  def initialize(attributes = {})
    super(attributes.merge(name: 'BreakoutScalper'))
  end

  def execute(instrument, market_data)
    return nil unless valid_for_trading?(instrument, market_data)

    breakout_signal = analyze_breakout(instrument, market_data)
    return nil unless breakout_signal

    build_trade_plan(
      instrument,
      breakout_signal[:side],
      market_data[:ltp],
      market_data,
      confidence: breakout_signal[:confidence],
      stop_loss_percentage: breakout_signal[:stop_loss_percentage] || 0.015,
      risk_reward_ratio: breakout_signal[:risk_reward_ratio] || 2.0
    )
  end

  def should_exit?(position, market_data)
    time_based_exit?(position, max_trade_duration.minutes) ||
      profit_target_hit?(position, market_data[:ltp]) ||
      stop_loss_hit?(position, market_data[:ltp]) ||
      false_breakout?(position, market_data) ||
      volume_drying_up?(position, market_data)
  end

  private

  def market_conditions_valid?(market_data)
    super(market_data) &&
      market_data[:candles].present? &&
      market_data[:candles].length >= lookback_periods &&
      market_data[:volume].present? &&
      market_data[:volume] > 0
  end

  def analyze_breakout(instrument, market_data)
    candles = market_data[:candles]
    return nil unless candles&.length >= lookback_periods

    # Find support and resistance levels
    levels = find_support_resistance_levels(candles)
    return nil unless levels[:support] && levels[:resistance]

    # Check for consolidation before breakout
    return nil unless consolidation_detected?(candles, levels)

    # Check for breakout
    breakout = detect_breakout(candles.last, levels, market_data)
    return nil unless breakout

    # Validate breakout with volume
    return nil unless volume_confirms_breakout?(breakout, market_data)

    build_breakout_signal(breakout, market_data)
  end

  def find_support_resistance_levels(candles)
    prices = candles.map { |c| [c[:high], c[:low], c[:close]] }.flatten
    return { support: nil, resistance: nil } if prices.empty?

    # Find significant levels using pivot points
    highs = candles.map { |c| c[:high] }
    lows = candles.map { |c| c[:low] }
    closes = candles.map { |c| c[:close] }

    # Calculate pivot points
    pivot_highs = find_pivot_highs(highs)
    pivot_lows = find_pivot_lows(lows)

    # Find most significant levels
    resistance = find_significant_level(pivot_highs, closes.last, 'resistance')
    support = find_significant_level(pivot_lows, closes.last, 'support')

    { support: support, resistance: resistance }
  end

  def find_pivot_highs(highs, window = 3)
    pivot_highs = []
    (window...highs.length - window).each do |i|
      if highs[i] == highs[i - window..i + window].max
        pivot_highs << { price: highs[i], index: i }
      end
    end
    pivot_highs
  end

  def find_pivot_lows(lows, window = 3)
    pivot_lows = []
    (window...lows.length - window).each do |i|
      if lows[i] == lows[i - window..i + window].min
        pivot_lows << { price: lows[i], index: i }
      end
    end
    pivot_lows
  end

  def find_significant_level(levels, current_price, type)
    return nil if levels.empty?

    # Filter levels near current price
    relevant_levels = levels.select do |level|
      price_diff = (level[:price] - current_price).abs / current_price
      price_diff <= 0.02 # Within 2%
    end

    return nil if relevant_levels.empty?

    # Find the most significant level (closest to current price)
    relevant_levels.min_by { |level| (level[:price] - current_price).abs }[:price]
  end

  def consolidation_detected?(candles, levels)
    return false unless levels[:support] && levels[:resistance]

    # Check if price has been consolidating between levels
    recent_candles = candles.last(consolidation_periods)
    return false if recent_candles.length < consolidation_periods

    recent_candles.all? do |candle|
      candle[:low] >= levels[:support] * 0.999 &&
      candle[:high] <= levels[:resistance] * 1.001
    end
  end

  def detect_breakout(last_candle, levels, market_data)
    current_price = market_data[:ltp]
    return nil unless current_price

    # Check for resistance breakout
    if levels[:resistance] && current_price > levels[:resistance] * (1 + breakout_threshold)
      {
        side: 'BUY',
        level: levels[:resistance],
        breakout_price: current_price,
        strength: calculate_breakout_strength(current_price, levels[:resistance])
      }
    # Check for support breakout
    elsif levels[:support] && current_price < levels[:support] * (1 - breakout_threshold)
      {
        side: 'SELL',
        level: levels[:support],
        breakout_price: current_price,
        strength: calculate_breakout_strength(levels[:support], current_price)
      }
    end
  end

  def calculate_breakout_strength(breakout_price, level)
    ((breakout_price - level).abs / level).round(4)
  end

  def volume_confirms_breakout?(breakout, market_data)
    return false unless market_data[:volume].present?

    # Check if volume is above average
    avg_volume = calculate_average_volume(market_data)
    return false unless avg_volume > 0

    current_volume = market_data[:volume]
    volume_ratio = current_volume / avg_volume

    volume_ratio >= volume_multiplier
  end

  def calculate_average_volume(market_data)
    return 0 unless market_data[:candles]&.length >= 10

    recent_candles = market_data[:candles].last(10)
    volumes = recent_candles.map { |c| c[:volume] || 0 }
    volumes.sum / volumes.length.to_f
  end

  def build_breakout_signal(breakout, market_data)
    confidence = calculate_breakout_confidence(breakout, market_data)
    return nil if confidence < min_confidence

    {
      side: breakout[:side],
      confidence: confidence,
      stop_loss_percentage: calculate_breakout_stop_loss_percentage(breakout),
      risk_reward_ratio: calculate_breakout_risk_reward_ratio(breakout),
      breakout_strength: breakout[:strength],
      level: breakout[:level],
      volume_ratio: calculate_volume_ratio(market_data)
    }
  end

  def calculate_breakout_confidence(breakout, market_data)
    # Base confidence from breakout strength
    strength_confidence = [breakout[:strength] * 10, 1.0].min

    # Volume confirmation
    volume_confidence = calculate_volume_confidence(market_data)

    # Price action confirmation
    price_action_confidence = calculate_price_action_confidence(breakout, market_data)

    # Weighted confidence
    (strength_confidence * 0.4 +
     volume_confidence * 0.3 +
     price_action_confidence * 0.3).round(3)
  end

  def calculate_volume_confidence(market_data)
    volume_ratio = calculate_volume_ratio(market_data)
    case volume_ratio
    when 0..1.0 then 0.3
    when 1.0..1.5 then 0.6
    when 1.5..2.0 then 0.8
    when 2.0..3.0 then 1.0
    else 0.9
    end
  end

  def calculate_volume_ratio(market_data)
    avg_volume = calculate_average_volume(market_data)
    return 0 unless avg_volume > 0

    current_volume = market_data[:volume] || 0
    current_volume / avg_volume
  end

  def calculate_price_action_confidence(breakout, market_data)
    return 0.5 unless market_data[:candles]&.length >= 3

    recent_candles = market_data[:candles].last(3)
    closes = recent_candles.map { |c| c[:close] }

    # Check for strong momentum
    if breakout[:side] == 'BUY'
      closes.last > closes.first ? 0.8 : 0.4
    else
      closes.last < closes.first ? 0.8 : 0.4
    end
  end

  def calculate_breakout_stop_loss_percentage(breakout)
    # Tighter stops for breakouts
    base_stop = 0.015
    strength_adjustment = breakout[:strength] * 0.005
    [base_stop - strength_adjustment, 0.01].max
  end

  def calculate_breakout_risk_reward_ratio(breakout)
    # Standard R:R for breakouts
    base_ratio = 2.0
    strength_adjustment = breakout[:strength] * 0.5
    base_ratio + strength_adjustment
  end

  def false_breakout?(position, market_data)
    return false unless market_data[:candles]&.length >= 3

    recent_candles = market_data[:candles].last(3)
    current_price = market_data[:ltp]

    # Check if price has reversed back through the breakout level
    case position.side
    when 'BUY'
      # Check if price fell back below resistance
      recent_candles.any? { |c| c[:close] < position.entry_price * 0.998 }
    when 'SELL'
      # Check if price rose back above support
      recent_candles.any? { |c| c[:close] > position.entry_price * 1.002 }
    else
      false
    end
  end

  def volume_drying_up?(position, market_data)
    return false unless market_data[:candles]&.length >= 5

    recent_volumes = market_data[:candles].last(5).map { |c| c[:volume] || 0 }
    return false if recent_volumes.any? { |v| v == 0 }

    # Check if volume is consistently decreasing
    recent_volumes.each_cons(2).all? { |a, b| b < a }
  end
end
