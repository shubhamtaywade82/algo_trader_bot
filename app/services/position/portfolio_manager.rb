# frozen_string_literal: true

# Portfolio manager for high-level position and risk management
class Position::PortfolioManager
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :total_capital, :decimal, default: 100_000.0
  attribute :max_portfolio_risk, :decimal, default: 0.10
  attribute :max_positions, :integer, default: 10
  attribute :max_correlation, :decimal, default: 0.7
  attribute :rebalance_threshold, :decimal, default: 0.05
  attribute :position_sizer, default: -> { Position::Sizer.new }
  attribute :exit_manager, default: -> { Position::ExitManager.new }
  attribute :monitor, default: -> { Position::Monitor.new }

  def initialize(attributes = {})
    super
    @portfolio_state = {}
    @last_rebalance = nil
  end

  # Get comprehensive portfolio overview
  def portfolio_overview
    {
      capital: total_capital,
      active_positions: active_positions.count,
      total_exposure: calculate_total_exposure,
      total_risk: calculate_total_risk,
      daily_pnl: calculate_daily_pnl,
      total_pnl: calculate_total_pnl,
      portfolio_value: calculate_portfolio_value,
      risk_utilization: calculate_risk_utilization,
      correlation_risk: calculate_correlation_risk,
      diversification_score: calculate_diversification_score,
      performance_metrics: calculate_performance_metrics
    }
  end

  # Add a new position to the portfolio
  def add_position(signal, instrument, market_data)
    return { success: false, error: 'Portfolio limits reached' } if at_position_limit?

    # Check portfolio constraints
    constraint_check = check_portfolio_constraints(signal, instrument)
    return constraint_check unless constraint_check[:allowed]

    # Calculate position size
    position_size = position_sizer.calculate_position_size(signal, instrument, market_data)
    return { success: false, error: 'Position size too small' } if position_size <= 0

    # Create position
    position = create_position(signal, instrument, position_size)
    return { success: false, error: 'Failed to create position' } unless position

    # Update portfolio state
    update_portfolio_state

    { success: true, position: position }
  end

  # Remove a position from the portfolio
  def remove_position(position, reason = 'manual_close')
    return { success: false, error: 'Position not found' } unless position&.active?

    # Execute exit
    exit_result = exit_manager.process_exit(position, reason)

    if exit_result
      update_portfolio_state
      { success: true, position: position }
    else
      { success: false, error: 'Failed to exit position' }
    end
  end

  # Rebalance portfolio if needed
  def rebalance_portfolio!
    return false unless should_rebalance?

    Rails.logger.info 'Starting portfolio rebalancing'

    # Calculate target allocations
    target_allocations = calculate_target_allocations

    # Rebalance positions
    rebalance_results = execute_rebalancing(target_allocations)

    @last_rebalance = Time.current
    update_portfolio_state

    Rails.logger.info "Portfolio rebalancing completed: #{rebalance_results[:success_count]} positions updated"
    rebalance_results
  end

  # Force close all positions
  def close_all_positions!(reason = 'portfolio_close')
    positions = TradingPosition.active
    results = []

    positions.each do |position|
      result = remove_position(position, reason)
      results << result
    end

    update_portfolio_state
    results
  end

  # Get portfolio performance metrics
  def performance_metrics
    {
      total_return: calculate_total_return,
      daily_return: calculate_daily_return,
      sharpe_ratio: calculate_sharpe_ratio,
      max_drawdown: calculate_max_drawdown,
      win_rate: calculate_win_rate,
      avg_win: calculate_avg_win,
      avg_loss: calculate_avg_loss,
      profit_factor: calculate_profit_factor
    }
  end

  # Get risk metrics
  def risk_metrics
    {
      portfolio_var: calculate_var,
      portfolio_volatility: calculate_portfolio_volatility,
      correlation_risk: calculate_correlation_risk,
      concentration_risk: calculate_concentration_risk,
      leverage_ratio: calculate_leverage_ratio
    }
  end

  # Get position recommendations
  def get_recommendations
    recommendations = []

    # Check for over-concentration
    if calculate_concentration_risk > 0.3
      recommendations << {
        type: 'concentration',
        message: 'Portfolio is over-concentrated in certain instruments',
        action: 'Consider diversifying positions'
      }
    end

    # Check for high correlation
    if calculate_correlation_risk > max_correlation
      recommendations << {
        type: 'correlation',
        message: 'Positions are highly correlated',
        action: 'Consider reducing correlated positions'
      }
    end

    # Check for risk limits
    if calculate_risk_utilization > max_portfolio_risk
      recommendations << {
        type: 'risk',
        message: 'Portfolio risk exceeds limits',
        action: 'Consider reducing position sizes or closing positions'
      }
    end

    recommendations
  end

  private

  def active_positions
    @active_positions ||= TradingPosition.active.includes(:instrument)
  end

  def at_position_limit?
    active_positions.count >= max_positions
  end

  def check_portfolio_constraints(signal, instrument)
    # Check correlation with existing positions
    if correlation_exceeds_limit?(instrument)
      return { allowed: false, error: 'Correlation with existing positions too high' }
    end

    # Check risk limits
    if would_exceed_risk_limit?(signal, instrument)
      return { allowed: false, error: 'Would exceed portfolio risk limits' }
    end

    # Check diversification
    if would_reduce_diversification?(instrument)
      return { allowed: false, error: 'Would reduce portfolio diversification' }
    end

    { allowed: true }
  end

  def correlation_exceeds_limit?(instrument)
    return false if active_positions.empty?

    max_corr = active_positions.map do |position|
      calculate_correlation(instrument, position.instrument)
    end.max

    max_corr > max_correlation
  end

  def would_exceed_risk_limit?(signal, instrument)
    current_risk = calculate_total_risk
    new_position_risk = calculate_position_risk(signal, instrument)

    (current_risk + new_position_risk) > (total_capital * max_portfolio_risk)
  end

  def would_reduce_diversification?(instrument)
    # Simplified diversification check
    # In practice, you'd use more sophisticated metrics
    active_positions.count >= 5 &&
      active_positions.any? { |p| p.instrument.symbol_name == instrument.symbol_name }
  end

  def create_position(signal, instrument, quantity)
    TradingPosition.create!(
      instrument: instrument,
      strategy: signal[:strategy],
      side: signal[:side],
      quantity: quantity,
      entry_price: signal[:entry_price],
      stop_loss: signal[:stop_loss],
      take_profit: signal[:take_profit],
      risk_per_trade: signal[:risk_per_trade] || 0.02,
      risk_reward_ratio: signal[:risk_reward_ratio] || 2.0,
      expected_profit: signal[:expected_profit],
      expected_loss: signal[:expected_loss],
      confidence: signal[:confidence] || 0.5,
      entry_time: Time.current,
      status: 'active'
    )
  end

  def calculate_total_exposure
    active_positions.sum { |p| p.quantity * p.entry_price }
  end

  def calculate_total_risk
    active_positions.sum { |p| p.risk_amount }
  end

  def calculate_daily_pnl
    TradingPosition.active.sum(:current_pnl)
  end

  def calculate_total_pnl
    TradingPosition.closed.sum(:current_pnl) + calculate_daily_pnl
  end

  def calculate_portfolio_value
    total_capital + calculate_total_pnl
  end

  def calculate_risk_utilization
    calculate_total_risk / total_capital
  end

  def calculate_correlation_risk
    return 0.0 if active_positions.count < 2

    correlations = []
    positions = active_positions.to_a

    (0...positions.length).each do |i|
      ((i + 1)...positions.length).each do |j|
        corr = calculate_correlation(positions[i].instrument, positions[j].instrument)
        correlations << corr
      end
    end

    correlations.max || 0.0
  end

  def calculate_diversification_score
    return 1.0 if active_positions.empty?

    # Simple diversification score based on number of unique instruments
    unique_instruments = active_positions.map(&:instrument).uniq.count
    [unique_instruments.to_f / max_positions, 1.0].min
  end

  def calculate_performance_metrics
    {
      total_return: calculate_total_return,
      daily_return: calculate_daily_return,
      sharpe_ratio: calculate_sharpe_ratio,
      max_drawdown: calculate_max_drawdown
    }
  end

  def calculate_total_return
    return 0.0 if total_capital <= 0

    (calculate_total_pnl / total_capital) * 100
  end

  def calculate_daily_return
    return 0.0 if total_capital <= 0

    (calculate_daily_pnl / total_capital) * 100
  end

  def calculate_sharpe_ratio
    # Simplified Sharpe ratio calculation
    # In practice, you'd use historical returns
    0.0
  end

  def calculate_max_drawdown
    # Simplified max drawdown calculation
    # In practice, you'd track historical portfolio values
    0.0
  end

  def calculate_var(confidence_level = 0.95)
    # Simplified VaR calculation
    # In practice, you'd use historical data and statistical methods
    0.0
  end

  def calculate_portfolio_volatility
    # Simplified portfolio volatility calculation
    # In practice, you'd use historical returns
    0.0
  end

  def calculate_concentration_risk
    return 0.0 if active_positions.empty?

    # Calculate Herfindahl index for concentration
    total_value = calculate_total_exposure
    return 0.0 if total_value <= 0

    concentrations = active_positions.map do |position|
      position_value = position.quantity * position.entry_price
      (position_value / total_value) ** 2
    end

    concentrations.sum
  end

  def calculate_leverage_ratio
    total_exposure = calculate_total_exposure
    return 0.0 if total_capital <= 0

    total_exposure / total_capital
  end

  def calculate_correlation(instrument1, instrument2)
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
    instrument1.symbol_name.include?('NIFTY') && instrument2.symbol_name.include?('NIFTY')
  end

  def same_market?(instrument1, instrument2)
    instrument1.exchange == instrument2.exchange
  end

  def calculate_position_risk(signal, instrument)
    stop_loss_distance = (signal[:entry_price] - signal[:stop_loss]).abs
    position_size = position_sizer.calculate_position_size(signal, instrument, {})
    position_size * stop_loss_distance
  end

  def should_rebalance?
    return false if @last_rebalance && @last_rebalance > 1.hour.ago

    # Check if any allocation has drifted beyond threshold
    current_allocations = calculate_current_allocations
    target_allocations = calculate_target_allocations

    current_allocations.any? do |instrument, allocation|
      target_allocation = target_allocations[instrument] || 0
      (allocation - target_allocation).abs > rebalance_threshold
    end
  end

  def calculate_current_allocations
    total_value = calculate_total_exposure
    return {} if total_value <= 0

    allocations = {}
    active_positions.each do |position|
      instrument = position.instrument
      value = position.quantity * position.entry_price
      allocations[instrument] = (allocations[instrument] || 0) + value
    end

    allocations.transform_values { |v| v / total_value }
  end

  def calculate_target_allocations
    # Simplified target allocation (equal weight)
    # In practice, you'd use more sophisticated allocation strategies
    return {} if active_positions.empty?

    equal_weight = 1.0 / active_positions.count
    allocations = {}

    active_positions.each do |position|
      allocations[position.instrument] = equal_weight
    end

    allocations
  end

  def execute_rebalancing(target_allocations)
    # Simplified rebalancing implementation
    # In practice, you'd implement more sophisticated rebalancing logic
    { success_count: 0, error_count: 0 }
  end

  def update_portfolio_state
    @portfolio_state = {
      total_capital: total_capital,
      active_positions_count: active_positions.count,
      total_exposure: calculate_total_exposure,
      total_risk: calculate_total_risk,
      last_updated: Time.current
    }
  end

  def calculate_win_rate
    closed_positions = TradingPosition.closed
    return 0.0 if closed_positions.empty?

    winning_positions = closed_positions.where('current_pnl > 0').count
    winning_positions.to_f / closed_positions.count
  end

  def calculate_avg_win
    winning_positions = TradingPosition.closed.where('current_pnl > 0')
    return 0.0 if winning_positions.empty?

    winning_positions.average(:current_pnl) || 0.0
  end

  def calculate_avg_loss
    losing_positions = TradingPosition.closed.where('current_pnl < 0')
    return 0.0 if losing_positions.empty?

    losing_positions.average(:current_pnl) || 0.0
  end

  def calculate_profit_factor
    gross_profit = TradingPosition.closed.where('current_pnl > 0').sum(:current_pnl)
    gross_loss = TradingPosition.closed.where('current_pnl < 0').sum(:current_pnl).abs

    return 0.0 if gross_loss == 0

    gross_profit / gross_loss
  end
end
