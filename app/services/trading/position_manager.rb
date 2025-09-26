# frozen_string_literal: true

# Position manager for tracking and managing trading positions
# Handles position lifecycle, P&L tracking, and risk management
class Trading::PositionManager
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :max_positions, :integer, default: 10
  attribute :max_position_size, :decimal, default: 100_000.0
  attribute :max_daily_loss, :decimal, default: 5_000.0
  attribute :position_timeout, :integer, default: 180 # 3 hours in minutes

  def initialize(attributes = {})
    super
    @positions = {}
    @daily_pnl = 0.0
    @last_reset_date = Date.current
  end

  # Update positions with current market data
  def update_positions(active_positions)
    reset_daily_pnl_if_needed

    active_positions.each do |position|
      update_position(position)
    end

    # Clean up expired positions
    cleanup_expired_positions
  end

  # Add a new position
  def add_position(position)
    @positions[position.id] = {
      position: position,
      entry_time: Time.current,
      max_profit: 0.0,
      max_loss: 0.0,
      last_update: Time.current
    }
  end

  # Remove a position
  def remove_position(position_id)
    @positions.delete(position_id)
  end

  # Get all active positions
  def active_positions
    @positions.values.map { |p| p[:position] }
  end

  # Get position by ID
  def get_position(position_id)
    @positions[position_id]&.dig(:position)
  end

  # Get position statistics
  def position_stats(position_id)
    pos_data = @positions[position_id]
    return nil unless pos_data

    {
      position: pos_data[:position],
      duration: Time.current - pos_data[:entry_time],
      max_profit: pos_data[:max_profit],
      max_loss: pos_data[:max_loss],
      current_pnl: calculate_current_pnl(pos_data[:position]),
      last_update: pos_data[:last_update]
    }
  end

  # Get all position statistics
  def all_position_stats
    @positions.map do |id, data|
      {
        id: id,
        position: data[:position],
        duration: Time.current - data[:entry_time],
        max_profit: data[:max_profit],
        max_loss: data[:max_loss],
        current_pnl: calculate_current_pnl(data[:position]),
        last_update: data[:last_update]
      }
    end
  end

  # Get daily P&L
  def daily_pnl
    reset_daily_pnl_if_needed
    @daily_pnl
  end

  # Check if daily loss limit is reached
  def daily_loss_limit_reached?
    daily_pnl <= -max_daily_loss
  end

  # Get portfolio statistics
  def portfolio_stats
    reset_daily_pnl_if_needed

    total_pnl = 0.0
    winning_positions = 0
    losing_positions = 0
    total_positions = @positions.size

    @positions.each do |_id, data|
      current_pnl = calculate_current_pnl(data[:position])
      total_pnl += current_pnl

      if current_pnl > 0
        winning_positions += 1
      elsif current_pnl < 0
        losing_positions += 1
      end
    end

    {
      total_positions: total_positions,
      active_positions: @positions.size,
      daily_pnl: @daily_pnl,
      total_pnl: total_pnl,
      winning_positions: winning_positions,
      losing_positions: losing_positions,
      win_rate: total_positions > 0 ? (winning_positions.to_f / total_positions * 100).round(2) : 0,
      max_daily_loss: max_daily_loss,
      daily_loss_limit_reached: daily_loss_limit_reached?
    }
  end

  # Get manager statistics
  def stats
    {
      max_positions: max_positions,
      current_positions: @positions.size,
      daily_pnl: daily_pnl,
      last_reset_date: @last_reset_date,
      portfolio: portfolio_stats
    }
  end

  # Force close all positions
  def close_all_positions!
    closed_count = 0

    @positions.each do |id, data|
      position = data[:position]
      next unless position.active?

      begin
        # This would trigger exit orders for all positions
        # In practice, you'd call the order executor
        Rails.logger.info "Force closing position #{id}: #{position.instrument.symbol}"
        closed_count += 1
      rescue StandardError => e
        Rails.logger.error "Failed to close position #{id}: #{e.message}"
      end
    end

    closed_count
  end

  # Check if position should be closed due to risk management
  def should_close_position?(position)
    return false unless position.active?

    # Check daily loss limit
    return true if daily_loss_limit_reached?

    # Check position timeout
    return true if position_aged_out?(position)

    # Check individual position loss
    current_pnl = calculate_current_pnl(position)
    return true if current_pnl <= -position.expected_loss * 1.5 # 1.5x expected loss

    false
  end

  private

  def update_position(position)
    return unless @positions[position.id]

    pos_data = @positions[position.id]
    current_pnl = calculate_current_pnl(position)

    # Update max profit/loss
    pos_data[:max_profit] = [pos_data[:max_profit], current_pnl].max
    pos_data[:max_loss] = [pos_data[:max_loss], current_pnl].min

    # Update last update time
    pos_data[:last_update] = Time.current

    # Update daily P&L
    @daily_pnl += current_pnl - (pos_data[:last_pnl] || 0)
    pos_data[:last_pnl] = current_pnl
  end

  def calculate_current_pnl(position)
    return 0.0 unless position.instrument&.ltp

    current_price = position.instrument.ltp
    case position.side.upcase
    when 'BUY'
      (current_price - position.entry_price) * position.quantity
    when 'SELL'
      (position.entry_price - current_price) * position.quantity
    else
      0.0
    end
  end

  def position_aged_out?(position)
    return false unless @positions[position.id]

    entry_time = @positions[position.id][:entry_time]
    Time.current - entry_time > position_timeout.minutes
  end

  def cleanup_expired_positions
    expired_positions = []

    @positions.each do |id, data|
      if position_aged_out?(data[:position])
        expired_positions << id
      end
    end

    expired_positions.each do |id|
      Rails.logger.info "Removing expired position #{id}"
      @positions.delete(id)
    end
  end

  def reset_daily_pnl_if_needed
    if Date.current > @last_reset_date
      @daily_pnl = 0.0
      @last_reset_date = Date.current
      Rails.logger.info "Daily P&L reset for #{Date.current}"
    end
  end

  def log_position_update(position, pnl)
    Rails.logger.debug "Position #{position.id} updated - P&L: #{pnl.round(2)}"
  end
end
