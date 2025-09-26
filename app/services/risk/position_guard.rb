# frozen_string_literal: true

# Position-level risk guard for individual position risk management
class Risk::PositionGuard
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :max_position_risk, :decimal, default: 0.05
  attribute :max_position_size, :decimal, default: 0.20
  attribute :max_drawdown, :decimal, default: 0.10
  attribute :max_holding_time, :integer, default: 240 # 4 hours in minutes
  attribute :min_confidence, :decimal, default: 0.6
  attribute :max_volatility, :decimal, default: 0.5
  attribute :min_risk_reward, :decimal, default: 1.5

  def initialize(attributes = {})
    super
    @risk_checks = []
  end

  # Check if a position can be opened
  def allow_position?(signal, instrument, market_data)
    @risk_checks = []

    # Run all risk checks
    check_position_size(signal, instrument)
    check_risk_amount(signal, instrument)
    check_confidence_level(signal)
    check_volatility(signal, market_data)
    check_risk_reward_ratio(signal)
    check_instrument_limits(instrument)
    check_market_conditions(market_data)

    # All checks must pass
    @risk_checks.all? { |check| check[:passed] }
  end

  # Check if a position should be closed due to risk
  def should_close_position?(position, market_data)
    @risk_checks = []

    # Run position monitoring checks
    check_position_drawdown(position)
    check_holding_time(position)
    check_volatility_exposure(position, market_data)
    check_risk_escalation(position)
    check_market_risk(position, market_data)

    # Any check can trigger closure
    @risk_checks.any? { |check| check[:passed] && check[:action] == 'close' }
  end

  # Get risk assessment for a position
  def assess_position_risk(position, market_data)
    @risk_checks = []

    # Run all risk assessments
    check_position_drawdown(position)
    check_holding_time(position)
    check_volatility_exposure(position, market_data)
    check_risk_escalation(position)
    check_market_risk(position, market_data)

    {
      risk_score: calculate_risk_score,
      risk_level: determine_risk_level,
      checks: @risk_checks,
      recommendations: generate_recommendations
    }
  end

  # Get risk checks that failed
  def failed_checks
    @risk_checks.select { |check| !check[:passed] }
  end

  # Get risk checks that passed
  def passed_checks
    @risk_checks.select { |check| check[:passed] }
  end

  private

  def check_position_size(signal, instrument)
    position_value = signal[:quantity] * signal[:entry_price]
    max_value = 100_000 * max_position_size # Assuming 100k capital

    check = {
      name: 'position_size',
      passed: position_value <= max_value,
      value: position_value,
      limit: max_value,
      message: "Position size: #{position_value.round(2)} (max: #{max_value.round(2)})"
    }

    @risk_checks << check
  end

  def check_risk_amount(signal, instrument)
    risk_amount = calculate_risk_amount(signal)
    max_risk = 100_000 * max_position_risk # Assuming 100k capital

    check = {
      name: 'risk_amount',
      passed: risk_amount <= max_risk,
      value: risk_amount,
      limit: max_risk,
      message: "Risk amount: #{risk_amount.round(2)} (max: #{max_risk.round(2)})"
    }

    @risk_checks << check
  end

  def check_confidence_level(signal)
    confidence = signal[:confidence] || 0.5

    check = {
      name: 'confidence_level',
      passed: confidence >= min_confidence,
      value: confidence,
      limit: min_confidence,
      message: "Confidence: #{(confidence * 100).round(1)}% (min: #{(min_confidence * 100).round(1)}%)"
    }

    @risk_checks << check
  end

  def check_volatility(signal, market_data)
    volatility = signal[:volatility] || market_data[:volatility] || 0.2

    check = {
      name: 'volatility',
      passed: volatility <= max_volatility,
      value: volatility,
      limit: max_volatility,
      message: "Volatility: #{(volatility * 100).round(1)}% (max: #{(max_volatility * 100).round(1)}%)"
    }

    @risk_checks << check
  end

  def check_risk_reward_ratio(signal)
    risk_reward = signal[:risk_reward_ratio] || 2.0

    check = {
      name: 'risk_reward_ratio',
      passed: risk_reward >= min_risk_reward,
      value: risk_reward,
      limit: min_risk_reward,
      message: "Risk/Reward: #{risk_reward.round(2)} (min: #{min_risk_reward.round(2)})"
    }

    @risk_checks << check
  end

  def check_instrument_limits(instrument)
    # Check if instrument has any specific limits
    # This would integrate with instrument-specific risk rules
    check = {
      name: 'instrument_limits',
      passed: true,
      value: 'N/A',
      limit: 'N/A',
      message: 'Instrument limits check passed'
    }

    @risk_checks << check
  end

  def check_market_conditions(market_data)
    # Check market-wide risk conditions
    market_risk = calculate_market_risk_score(market_data)
    max_market_risk = 0.8

    check = {
      name: 'market_conditions',
      passed: market_risk <= max_market_risk,
      value: market_risk,
      limit: max_market_risk,
      message: "Market risk: #{(market_risk * 100).round(1)}% (max: #{(max_market_risk * 100).round(1)}%)"
    }

    @risk_checks << check
  end

  def check_position_drawdown(position)
    return unless position.current_pnl

    drawdown = position.current_pnl / position.entry_price
    max_dd = -max_drawdown

    check = {
      name: 'position_drawdown',
      passed: drawdown >= max_dd,
      value: drawdown,
      limit: max_dd,
      message: "Drawdown: #{(drawdown * 100).round(2)}% (max: #{(max_dd * 100).round(2)}%)",
      action: drawdown < max_dd ? 'close' : 'monitor'
    }

    @risk_checks << check
  end

  def check_holding_time(position)
    holding_time = position.duration_minutes

    check = {
      name: 'holding_time',
      passed: holding_time <= max_holding_time,
      value: holding_time,
      limit: max_holding_time,
      message: "Holding time: #{holding_time}min (max: #{max_holding_time}min)",
      action: holding_time > max_holding_time ? 'close' : 'monitor'
    }

    @risk_checks << check
  end

  def check_volatility_exposure(position, market_data)
    return unless market_data[:volatility]

    volatility = market_data[:volatility]
    exposure = position.quantity * position.entry_price

    # Higher volatility with larger position = higher risk
    risk_score = volatility * (exposure / 100_000) # Normalize to 100k capital

    check = {
      name: 'volatility_exposure',
      passed: risk_score <= 0.1,
      value: risk_score,
      limit: 0.1,
      message: "Volatility exposure: #{(risk_score * 100).round(2)}% (max: 10%)",
      action: risk_score > 0.1 ? 'close' : 'monitor'
    }

    @risk_checks << check
  end

  def check_risk_escalation(position)
    # Check if risk has escalated beyond acceptable levels
    current_risk = position.current_pnl.abs
    expected_risk = position.expected_loss.abs
    risk_multiple = expected_risk > 0 ? current_risk / expected_risk : 0

    check = {
      name: 'risk_escalation',
      passed: risk_multiple <= 2.0,
      value: risk_multiple,
      limit: 2.0,
      message: "Risk escalation: #{risk_multiple.round(2)}x expected (max: 2.0x)",
      action: risk_multiple > 2.0 ? 'close' : 'monitor'
    }

    @risk_checks << check
  end

  def check_market_risk(position, market_data)
    # Check market-wide risk conditions
    market_risk = calculate_market_risk_score(market_data)

    check = {
      name: 'market_risk',
      passed: market_risk <= 0.8,
      value: market_risk,
      limit: 0.8,
      message: "Market risk: #{(market_risk * 100).round(1)}% (max: 80%)",
      action: market_risk > 0.8 ? 'close' : 'monitor'
    }

    @risk_checks << check
  end

  def calculate_risk_amount(signal)
    stop_loss_distance = (signal[:entry_price] - signal[:stop_loss]).abs
    signal[:quantity] * stop_loss_distance
  end

  def calculate_market_risk_score(market_data)
    # Simplified market risk calculation
    # In practice, you'd use more sophisticated market risk models
    volatility = market_data[:volatility] || 0.2
    trend_strength = market_data[:trend_strength] || 0.5

    # Higher volatility and lower trend strength = higher risk
    (volatility * (1 - trend_strength)).round(3)
  end

  def calculate_risk_score
    return 0.0 if @risk_checks.empty?

    failed_checks_count = failed_checks.count
    total_checks_count = @risk_checks.count

    (failed_checks_count.to_f / total_checks_count).round(3)
  end

  def determine_risk_level
    risk_score = calculate_risk_score

    case risk_score
    when 0.0..0.2 then 'low'
    when 0.2..0.5 then 'medium'
    when 0.5..0.8 then 'high'
    else 'critical'
    end
  end

  def generate_recommendations
    recommendations = []

    failed_checks.each do |check|
      case check[:name]
      when 'position_size'
        recommendations << 'Reduce position size to stay within limits'
      when 'risk_amount'
        recommendations << 'Reduce risk amount or tighten stop loss'
      when 'confidence_level'
        recommendations << 'Wait for higher confidence signal'
      when 'volatility'
        recommendations << 'Avoid trading in high volatility conditions'
      when 'risk_reward_ratio'
        recommendations << 'Improve risk-reward ratio before entering'
      when 'market_conditions'
        recommendations << 'Wait for better market conditions'
      end
    end

    recommendations.uniq
  end
end
