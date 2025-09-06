# frozen_string_literal: true

# Position sizing service for calculating optimal position sizes
# based on risk management rules and market conditions
class Position::Sizer
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :capital, :decimal, default: 100_000.0
  attribute :max_risk_per_trade, :decimal, default: 0.02
  attribute :max_portfolio_risk, :decimal, default: 0.10
  attribute :max_position_size, :decimal, default: 0.20
  attribute :min_position_size, :decimal, default: 0.01
  attribute :volatility_adjustment, :boolean, default: true
  attribute :correlation_adjustment, :boolean, default: true

  def initialize(attributes = {})
    super
    @active_positions = []
  end

  # Calculate position size for a given trade signal
  def calculate_position_size(signal, instrument, market_data)
    return 0 unless valid_signal?(signal) && valid_instrument?(instrument)

    # Get current portfolio state
    portfolio_state = get_portfolio_state

    # Calculate base position size
    base_size = calculate_base_size(signal, instrument, market_data)
    return 0 if base_size <= 0

    # Apply risk adjustments
    adjusted_size = apply_risk_adjustments(base_size, signal, instrument, portfolio_state)

    # Apply portfolio constraints
    final_size = apply_portfolio_constraints(adjusted_size, signal, instrument, portfolio_state)

    # Round to valid lot size
    round_to_lot_size(final_size, instrument)
  end

  # Calculate position size based on fixed risk amount
  def calculate_fixed_risk_size(risk_amount, stop_loss_distance, instrument)
    return 0 if risk_amount <= 0 || stop_loss_distance <= 0

    base_size = risk_amount / stop_loss_distance
    round_to_lot_size(base_size, instrument)
  end

  # Calculate position size based on percentage of capital
  def calculate_percentage_size(percentage, entry_price, instrument)
    return 0 if percentage <= 0 || entry_price <= 0

    position_value = capital * percentage
    base_size = position_value / entry_price
    round_to_lot_size(base_size, instrument)
  end

  # Calculate position size based on volatility
  def calculate_volatility_size(signal, instrument, market_data)
    return 0 unless market_data[:volatility]

    # Higher volatility = smaller position size
    volatility_factor = calculate_volatility_factor(market_data[:volatility])
    base_size = calculate_base_size(signal, instrument, market_data)

    round_to_lot_size(base_size * volatility_factor, instrument)
  end

  # Calculate position size based on Kelly Criterion
  def calculate_kelly_size(signal, instrument, market_data)
    return 0 unless signal[:confidence] && signal[:risk_reward_ratio]

    win_probability = signal[:confidence]
    win_loss_ratio = signal[:risk_reward_ratio]

    # Kelly formula: f = (bp - q) / b
    # where b = win/loss ratio, p = win probability, q = loss probability
    kelly_fraction = (win_loss_ratio * win_probability - (1 - win_probability)) / win_loss_ratio

    # Cap Kelly at 25% of capital
    kelly_fraction = [kelly_fraction, 0.25].min
    kelly_fraction = [kelly_fraction, 0.0].max

    return 0 if kelly_fraction <= 0

    position_value = capital * kelly_fraction
    base_size = position_value / signal[:entry_price]

    round_to_lot_size(base_size, instrument)
  end

  # Get current portfolio state for risk calculations
  def get_portfolio_state
    {
      total_capital: capital,
      active_positions: @active_positions,
      total_exposure: calculate_total_exposure,
      total_risk: calculate_total_risk,
      correlation_matrix: calculate_correlation_matrix
    }
  end

  # Update active positions for correlation calculations
  def update_active_positions(positions)
    @active_positions = positions
  end

  private

  def valid_signal?(signal)
    signal.present? &&
      signal[:entry_price].present? &&
      signal[:entry_price] > 0 &&
      signal[:stop_loss].present? &&
      signal[:stop_loss] > 0
  end

  def valid_instrument?(instrument)
    instrument.present? &&
      instrument.lot_size.present? &&
      instrument.lot_size > 0
  end

  def calculate_base_size(signal, instrument, market_data)
    # Calculate risk amount based on capital and risk per trade
    risk_amount = capital * max_risk_per_trade

    # Calculate stop loss distance
    stop_loss_distance = (signal[:entry_price] - signal[:stop_loss]).abs

    # Base size = risk amount / stop loss distance
    risk_amount / stop_loss_distance
  end

  def apply_risk_adjustments(base_size, signal, instrument, portfolio_state)
    adjusted_size = base_size

    # Confidence adjustment
    if signal[:confidence]
      confidence_factor = [signal[:confidence], 0.5].max
      adjusted_size *= confidence_factor
    end

    # Volatility adjustment
    if volatility_adjustment && signal[:volatility]
      volatility_factor = calculate_volatility_factor(signal[:volatility])
      adjusted_size *= volatility_factor
    end

    # Correlation adjustment
    if correlation_adjustment
      correlation_factor = calculate_correlation_factor(instrument, portfolio_state)
      adjusted_size *= correlation_factor
    end

    # Market condition adjustment
    market_factor = calculate_market_condition_factor(signal, instrument)
    adjusted_size *= market_factor

    adjusted_size
  end

  def apply_portfolio_constraints(adjusted_size, signal, instrument, portfolio_state)
    # Maximum position size constraint
    max_size_value = capital * max_position_size
    max_size_quantity = max_size_value / signal[:entry_price]
    adjusted_size = [adjusted_size, max_size_quantity].min

    # Minimum position size constraint
    min_size_value = capital * min_position_size
    min_size_quantity = min_size_value / signal[:entry_price]
    adjusted_size = [adjusted_size, min_size_quantity].max

    # Portfolio risk constraint
    if portfolio_state[:total_risk] + calculate_position_risk(adjusted_size, signal) > capital * max_portfolio_risk
      # Reduce size to stay within portfolio risk limit
      remaining_risk = (capital * max_portfolio_risk) - portfolio_state[:total_risk]
      max_risk_size = remaining_risk / (signal[:entry_price] - signal[:stop_loss]).abs
      adjusted_size = [adjusted_size, max_risk_size].min
    end

    # Maximum number of positions constraint
    if @active_positions.length >= 10 # Max 10 positions
      adjusted_size = 0
    end

    adjusted_size
  end

  def calculate_volatility_factor(volatility)
    # Normalize volatility (assuming 0.2 is average)
    normalized_vol = volatility / 0.2

    # Higher volatility = smaller position
    case normalized_vol
    when 0.0..0.5 then 1.2  # Low volatility
    when 0.5..1.0 then 1.0  # Normal volatility
    when 1.0..1.5 then 0.8  # High volatility
    when 1.5..2.0 then 0.6  # Very high volatility
    else 0.4                # Extreme volatility
    end
  end

  def calculate_correlation_factor(instrument, portfolio_state)
    return 1.0 if @active_positions.empty?

    # Calculate average correlation with existing positions
    correlations = @active_positions.map do |position|
      calculate_instrument_correlation(instrument, position.instrument)
    end

    avg_correlation = correlations.sum / correlations.length

    # Higher correlation = smaller position
    case avg_correlation
    when 0.0..0.3 then 1.0    # Low correlation
    when 0.3..0.6 then 0.8    # Medium correlation
    when 0.6..0.8 then 0.6    # High correlation
    else 0.4                  # Very high correlation
    end
  end

  def calculate_instrument_correlation(instrument1, instrument2)
    # Simplified correlation calculation
    # In practice, you'd use historical price data
    if instrument1.symbol_name == instrument2.symbol_name
      1.0
    elsif same_sector?(instrument1, instrument2)
      0.7
    elsif same_market?(instrument1, instrument2)
      0.4
    else
      0.1
    end
  end

  def same_sector?(instrument1, instrument2)
    # Simplified sector check
    # In practice, you'd have sector information
    instrument1.symbol_name.include?('NIFTY') && instrument2.symbol_name.include?('NIFTY')
  end

  def same_market?(instrument1, instrument2)
    # Simplified market check
    instrument1.exchange == instrument2.exchange
  end

  def calculate_market_condition_factor(signal, instrument)
    # Adjust based on market conditions
    # This would integrate with market data
    1.0
  end

  def calculate_total_exposure
    @active_positions.sum do |position|
      position.quantity * position.entry_price
    end
  end

  def calculate_total_risk
    @active_positions.sum do |position|
      position.risk_amount
    end
  end

  def calculate_correlation_matrix
    # Simplified correlation matrix
    # In practice, you'd calculate actual correlations
    {}
  end

  def calculate_position_risk(quantity, signal)
    stop_loss_distance = (signal[:entry_price] - signal[:stop_loss]).abs
    quantity * stop_loss_distance
  end

  def round_to_lot_size(quantity, instrument)
    return 0 if quantity <= 0 || instrument.lot_size <= 0

    (quantity / instrument.lot_size).floor * instrument.lot_size
  end
end
