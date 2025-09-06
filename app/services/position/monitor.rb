# frozen_string_literal: true

# Position monitoring service for real-time position tracking and updates
class Position::Monitor
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :update_interval, :integer, default: 30 # seconds
  attribute :max_positions, :integer, default: 50
  attribute :alert_thresholds, default: -> { default_alert_thresholds }
  attribute :monitoring_enabled, :boolean, default: true

  def initialize(attributes = {})
    super
    @monitoring_thread = nil
    @monitoring_active = false
    @position_cache = {}
    @last_update = {}
  end

  # Start monitoring all active positions
  def start_monitoring!
    return false if @monitoring_active

    @monitoring_active = true
    @monitoring_thread = Thread.new do
      monitoring_loop
    end

    Rails.logger.info "Position monitoring started with #{update_interval}s interval"
    true
  end

  # Stop monitoring
  def stop_monitoring!
    return false unless @monitoring_active

    @monitoring_active = false
    @monitoring_thread&.join(5) # Wait up to 5 seconds for graceful shutdown

    Rails.logger.info 'Position monitoring stopped'
    true
  end

  # Check if monitoring is active
  def monitoring?
    @monitoring_active
  end

  # Update a single position
  def update_position(position)
    return false unless position&.active?

    begin
      # Get current market data
      current_price = get_current_price(position.instrument)
      return false unless current_price

      # Update position
      position.update_current_price(current_price)

      # Check for exit conditions
      check_exit_conditions(position)

      # Update trailing stops
      update_trailing_stops(position)

      # Check alert conditions
      check_alert_conditions(position)

      # Cache position data
      cache_position_data(position)

      true
    rescue StandardError => e
      Rails.logger.error "Failed to update position #{position.id}: #{e.message}"
      false
    end
  end

  # Update all active positions
  def update_all_positions
    return false unless monitoring_enabled

    positions = TradingPosition.active.limit(max_positions)
    updated_count = 0

    positions.each do |position|
      updated_count += 1 if update_position(position)
    end

    Rails.logger.debug "Updated #{updated_count} positions"
    updated_count
  end

  # Get position statistics
  def position_stats
    {
      total_active: TradingPosition.active.count,
      total_closed_today: TradingPosition.closed.today.count,
      total_pnl: TradingPosition.active.sum(:current_pnl),
      profitable_positions: TradingPosition.active.profitable.count,
      losing_positions: TradingPosition.active.losing.count,
      monitoring_active: @monitoring_active,
      last_update: @last_update
    }
  end

  # Get alerts for positions
  def get_alerts
    alerts = []

    TradingPosition.active.each do |position|
      position_alerts = check_position_alerts(position)
      alerts.concat(position_alerts) if position_alerts.any?
    end

    alerts
  end

  # Force update all positions (bypass cache)
  def force_update_all!
    @position_cache.clear
    update_all_positions
  end

  private

  def default_alert_thresholds
    {
      profit_alert: 0.05,      # 5% profit
      loss_alert: -0.03,       # 3% loss
      time_alert: 120,         # 2 hours
      volatility_alert: 0.3,   # 30% volatility
      drawdown_alert: -0.05    # 5% drawdown
    }
  end

  def monitoring_loop
    Rails.logger.info 'Position monitoring loop started'

    while @monitoring_active
      begin
        update_all_positions
        sleep(update_interval)
      rescue StandardError => e
        Rails.logger.error "Position monitoring error: #{e.message}"
        sleep(update_interval * 2) # Sleep longer on error
      end
    end

    Rails.logger.info 'Position monitoring loop ended'
  end

  def get_current_price(instrument)
    # Try to get price from instrument
    price = instrument.ltp
    return price if price && price > 0

    # Fallback to market data service
    market_data = get_market_data(instrument)
    market_data&.dig(:ltp)
  end

  def get_market_data(instrument)
    # This would integrate with your market data service
    # For now, return nil to use instrument.ltp
    nil
  end

  def check_exit_conditions(position)
    return unless position.active?

    current_price = position.current_price
    return unless current_price

    # Check stop loss
    if position.stop_loss_hit?(current_price) && !position.stop_loss_hit
      trigger_exit(position, 'stop_loss', current_price)
      return
    end

    # Check take profit
    if position.take_profit_hit?(current_price) && !position.take_profit_hit
      trigger_exit(position, 'take_profit', current_price)
      return
    end

    # Check trailing stop
    if position.trailing_stop_hit?(current_price)
      trigger_exit(position, 'trailing_stop', current_price)
      return
    end

    # Check time-based exit
    if position.duration_hours > 4 # 4 hours max
      trigger_exit(position, 'time_exit', current_price)
      return
    end
  end

  def trigger_exit(position, reason, exit_price)
    Rails.logger.info "Triggering exit for position #{position.id}: #{reason} at #{exit_price}"

    position.close_position!(exit_price, reason)

    # Update flags
    case reason
    when 'stop_loss'
      position.update!(stop_loss_hit: true)
    when 'take_profit'
      position.update!(take_profit_hit: true)
    when 'time_exit'
      position.update!(time_exit_triggered: true)
    end
  end

  def update_trailing_stops(position)
    return unless position.trailing_stop_active?

    current_price = position.current_price
    return unless current_price

    position.update_trailing_stop(current_price)
  end

  def check_alert_conditions(position)
    alerts = check_position_alerts(position)

    alerts.each do |alert|
      Rails.logger.warn "Position Alert: #{alert[:message]}"
      # In a real system, you'd send notifications here
    end
  end

  def check_position_alerts(position)
    alerts = []
    current_price = position.current_price
    return alerts unless current_price

    # Profit alert
    if position.calculate_percentage_pnl(current_price) >= alert_thresholds[:profit_alert] * 100
      alerts << {
        type: 'profit',
        position_id: position.id,
        message: "Position #{position.id} reached #{position.calculate_percentage_pnl(current_price).round(2)}% profit"
      }
    end

    # Loss alert
    if position.calculate_percentage_pnl(current_price) <= alert_thresholds[:loss_alert] * 100
      alerts << {
        type: 'loss',
        position_id: position.id,
        message: "Position #{position.id} reached #{position.calculate_percentage_pnl(current_price).round(2)}% loss"
      }
    end

    # Time alert
    if position.duration_hours >= alert_thresholds[:time_alert]
      alerts << {
        type: 'time',
        position_id: position.id,
        message: "Position #{position.id} has been open for #{position.duration_hours.round(1)} hours"
      }
    end

    # Risk alert
    if position.risk_reward_achieved >= 2.0
      alerts << {
        type: 'risk_reward',
        position_id: position.id,
        message: "Position #{position.id} achieved 2:1 risk-reward ratio"
      }
    end

    alerts
  end

  def cache_position_data(position)
    @position_cache[position.id] = {
      last_price: position.current_price,
      last_pnl: position.current_pnl,
      last_update: Time.current
    }
  end

  def should_update_position?(position)
    return true unless @position_cache[position.id]

    cached_data = @position_cache[position.id]
    last_update = cached_data[:last_update]

    # Update if more than 30 seconds have passed
    Time.current - last_update > 30.seconds
  end
end
