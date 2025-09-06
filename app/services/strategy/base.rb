# frozen_string_literal: true

# Base class for all trading strategies
# Provides common interface and validation for strategy implementations
class Strategy::Base
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :name, :string
  attribute :enabled, :boolean, default: true
  attribute :risk_per_trade, :decimal, default: 0.02
  attribute :max_positions, :integer, default: 3
  attribute :min_confidence, :decimal, default: 0.6
  attribute :capital_allocation, :decimal, default: 100_000.0

  def initialize(attributes = {})
    super
    validate!
  end

  # Main execution method - must be implemented by subclasses
  def execute(instrument, market_data)
    raise NotImplementedError, "Subclasses must implement #execute"
  end

  # Exit condition check - must be implemented by subclasses
  def should_exit?(position, market_data)
    raise NotImplementedError, "Subclasses must implement #should_exit?"
  end

  # Check if strategy is valid for trading
  def valid_for_trading?(instrument, market_data)
    enabled? &&
      instrument_valid?(instrument) &&
      market_conditions_valid?(market_data) &&
      confidence_sufficient?(market_data)
  end

  # Calculate position size based on risk management
  def calculate_position_size(instrument, market_data, stop_loss_distance)
    return 0 if stop_loss_distance <= 0

    risk_amount = risk_per_trade * capital_allocation
    (risk_amount / stop_loss_distance).floor
  end

  # Calculate stop loss price
  def calculate_stop_loss(side, entry_price, stop_loss_percentage = 0.02)
    case side.upcase
    when 'BUY'
      entry_price * (1 - stop_loss_percentage)
    when 'SELL'
      entry_price * (1 + stop_loss_percentage)
    else
      entry_price
    end
  end

  # Calculate take profit price
  def calculate_take_profit(side, entry_price, risk_reward_ratio = 2.0, stop_loss_percentage = 0.02)
    profit_percentage = stop_loss_percentage * risk_reward_ratio
    case side.upcase
    when 'BUY'
      entry_price * (1 + profit_percentage)
    when 'SELL'
      entry_price * (1 - profit_percentage)
    else
      entry_price
    end
  end

  # Build trade plan structure
  def build_trade_plan(instrument, side, entry_price, market_data, options = {})
    stop_loss = calculate_stop_loss(side, entry_price, options[:stop_loss_percentage] || 0.02)
    take_profit = calculate_take_profit(side, entry_price, options[:risk_reward_ratio] || 2.0, options[:stop_loss_percentage] || 0.02)
    stop_loss_distance = (entry_price - stop_loss).abs

    quantity = calculate_position_size(instrument, market_data, stop_loss_distance)
    return nil if quantity <= 0

    {
      instrument: instrument,
      side: side.upcase,
      quantity: quantity,
      entry_price: entry_price,
      stop_loss: stop_loss,
      take_profit: take_profit,
      confidence: options[:confidence] || 0.5,
      strategy: name,
      risk_reward_ratio: options[:risk_reward_ratio] || 2.0,
      stop_loss_percentage: options[:stop_loss_percentage] || 0.02,
      expected_profit: (take_profit - entry_price).abs * quantity * (side.upcase == 'BUY' ? 1 : -1),
      expected_loss: (entry_price - stop_loss).abs * quantity * (side.upcase == 'BUY' ? 1 : -1),
      created_at: Time.current
    }
  end

  # Calculate current P&L for a position
  def calculate_current_pnl(position, current_price = nil)
    current_price ||= position.instrument.ltp
    case position.side.upcase
    when 'BUY'
      (current_price - position.entry_price) * position.quantity
    when 'SELL'
      (position.entry_price - current_price) * position.quantity
    else
      0
    end
  end

  # Check if position should exit based on time
  def time_based_exit?(position, max_duration = 30.minutes)
    position.created_at < max_duration.ago
  end

  # Check if profit target is hit
  def profit_target_hit?(position, current_price = nil)
    current_pnl = calculate_current_pnl(position, current_price)
    current_pnl >= position.expected_profit * 0.8 # 80% of target
  end

  # Check if stop loss is hit
  def stop_loss_hit?(position, current_price = nil)
    current_pnl = calculate_current_pnl(position, current_price)
    current_pnl <= -position.expected_loss
  end

  private

  def validate!
    raise ArgumentError, "Strategy name is required" if name.blank?
    raise ArgumentError, "Risk per trade must be between 0 and 1" unless (0..1).cover?(risk_per_trade)
    raise ArgumentError, "Max positions must be positive" unless max_positions > 0
    raise ArgumentError, "Min confidence must be between 0 and 1" unless (0..1).cover?(min_confidence)
    raise ArgumentError, "Capital allocation must be positive" unless capital_allocation > 0
  end

  def instrument_valid?(instrument)
    instrument.present? && instrument.derivative?
  end

  def market_conditions_valid?(market_data)
    market_data.present? &&
      market_data[:ltp].present? &&
      market_data[:ltp] > 0 &&
      market_data[:volume].present? &&
      market_data[:volume] > 0
  end

  def confidence_sufficient?(market_data)
    return true unless market_data[:confidence].present?
    market_data[:confidence] >= min_confidence
  end
end
