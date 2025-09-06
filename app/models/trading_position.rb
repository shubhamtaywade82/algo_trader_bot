# frozen_string_literal: true

# Trading position model for managing individual trading positions
class TradingPosition < ApplicationRecord
  belongs_to :instrument

  # Status constants
  STATUS_ACTIVE = 'active'.freeze
  STATUS_CLOSED = 'closed'.freeze
  STATUS_CANCELLED = 'cancelled'.freeze

  # Side constants
  SIDE_BUY = 'BUY'.freeze
  SIDE_SELL = 'SELL'.freeze

  # Exit reason constants
  EXIT_REASONS = %w[
    stop_loss
    take_profit
    time_exit
    risk_exit
    manual_close
    strategy_exit
    system_exit
  ].freeze

  # Validations
  validates :strategy, presence: true
  validates :side, inclusion: { in: [SIDE_BUY, SIDE_SELL] }
  validates :quantity, presence: true, numericality: { greater_than: 0 }
  validates :entry_price, presence: true, numericality: { greater_than: 0 }
  validates :status, inclusion: { in: [STATUS_ACTIVE, STATUS_CLOSED, STATUS_CANCELLED] }
  validates :risk_per_trade, numericality: { in: 0..1 }
  validates :confidence, numericality: { in: 0..1 }
  validates :client_ref, uniqueness: true, allow_nil: true

  # Scopes
  scope :active, -> { where(status: STATUS_ACTIVE) }
  scope :closed, -> { where(status: STATUS_CLOSED) }
  scope :cancelled, -> { where(status: STATUS_CANCELLED) }
  scope :buy_positions, -> { where(side: SIDE_BUY) }
  scope :sell_positions, -> { where(side: SIDE_SELL) }
  scope :by_strategy, ->(strategy) { where(strategy: strategy) }
  scope :profitable, -> { where('current_pnl > 0') }
  scope :losing, -> { where('current_pnl < 0') }
  scope :breakeven, -> { where(current_pnl: 0) }
  scope :recent, ->(hours = 24) { where('entry_time >= ?', hours.hours.ago) }
  scope :today, -> { where(entry_time: Date.current.all_day) }

  # Callbacks
  before_save :update_duration
  before_save :update_current_pnl
  after_save :update_max_pnl_tracking

  # Instance methods

  def active?
    status == STATUS_ACTIVE
  end

  def closed?
    status == STATUS_CLOSED
  end

  def cancelled?
    status == STATUS_CANCELLED
  end

  def buy?
    side == SIDE_BUY
  end

  def sell?
    side == SIDE_SELL
  end

  def profitable?
    current_pnl > 0
  end

  def losing?
    current_pnl < 0
  end

  def breakeven?
    current_pnl == 0
  end

  def duration_hours
    return 0 unless entry_time

    ((last_update_time || Time.current) - entry_time) / 1.hour
  end

  def duration_minutes
    return 0 unless entry_time

    ((last_update_time || Time.current) - entry_time) / 1.minute
  end

  def calculate_current_pnl(price = nil)
    price ||= current_price || instrument&.ltp
    return 0.0 unless price && entry_price

    case side
    when SIDE_BUY
      (price - entry_price) * quantity
    when SIDE_SELL
      (entry_price - price) * quantity
    else
      0.0
    end
  end

  def calculate_percentage_pnl(price = nil)
    price ||= current_price || instrument&.ltp
    return 0.0 unless price && entry_price

    case side
    when SIDE_BUY
      ((price - entry_price) / entry_price) * 100
    when SIDE_SELL
      ((entry_price - price) / entry_price) * 100
    else
      0.0
    end
  end

  def risk_amount
    return 0.0 unless expected_loss

    expected_loss.abs
  end

  def reward_amount
    return 0.0 unless expected_profit

    expected_profit.abs
  end

  def risk_reward_achieved
    return 0.0 unless risk_amount > 0

    current_pnl.abs / risk_amount
  end

  def stop_loss_distance
    return 0.0 unless stop_loss && entry_price

    (entry_price - stop_loss).abs
  end

  def take_profit_distance
    return 0.0 unless take_profit && entry_price

    (take_profit - entry_price).abs
  end

  def stop_loss_percentage
    return 0.0 unless stop_loss && entry_price

    (stop_loss_distance / entry_price) * 100
  end

  def take_profit_percentage
    return 0.0 unless take_profit && entry_price

    (take_profit_distance / entry_price) * 100
  end

  def update_current_price(price)
    self.current_price = price
    self.last_update_time = Time.current
    save!
  end

  def close_position!(exit_price, reason = 'manual_close')
    self.exit_price = exit_price
    self.exit_reason = reason
    self.exit_time = Time.current
    self.status = STATUS_CLOSED
    self.current_pnl = calculate_current_pnl(exit_price)
    save!
  end

  def cancel_position!(reason = 'manual_cancel')
    self.exit_reason = reason
    self.exit_time = Time.current
    self.status = STATUS_CANCELLED
    self.current_pnl = 0.0
    save!
  end

  def should_trail_stop?
    return false unless trailing_stop_active && take_profit && entry_price

    case side
    when SIDE_BUY
      current_price > entry_price * 1.02 # 2% profit
    when SIDE_SELL
      current_price < entry_price * 0.98 # 2% profit
    else
      false
    end
  end

  def update_trailing_stop(price)
    return unless should_trail_stop?

    new_trailing_stop = case side
                        when SIDE_BUY
                          price * (1 - trailing_stop_percentage / 100)
                        when SIDE_SELL
                          price * (1 + trailing_stop_percentage / 100)
                        end

    if new_trailing_stop && (trailing_stop_price.nil? ||
        (side == SIDE_BUY && new_trailing_stop > trailing_stop_price) ||
        (side == SIDE_SELL && new_trailing_stop < trailing_stop_price))
      self.trailing_stop_price = new_trailing_stop
      save!
    end
  end

  def stop_loss_hit?(price = nil)
    price ||= current_price || instrument&.ltp
    return false unless price && stop_loss

    case side
    when SIDE_BUY
      price <= stop_loss
    when SIDE_SELL
      price >= stop_loss
    else
      false
    end
  end

  def take_profit_hit?(price = nil)
    price ||= current_price || instrument&.ltp
    return false unless price && take_profit

    case side
    when SIDE_BUY
      price >= take_profit
    when SIDE_SELL
      price <= take_profit
    else
      false
    end
  end

  def trailing_stop_hit?(price = nil)
    price ||= current_price || instrument&.ltp
    return false unless price && trailing_stop_price

    case side
    when SIDE_BUY
      price <= trailing_stop_price
    when SIDE_SELL
      price >= trailing_stop_price
    else
      false
    end
  end

  def to_summary
    {
      id: id,
      instrument: instrument&.symbol_name,
      strategy: strategy,
      side: side,
      quantity: quantity,
      entry_price: entry_price,
      current_price: current_price,
      current_pnl: current_pnl,
      percentage_pnl: calculate_percentage_pnl,
      stop_loss: stop_loss,
      take_profit: take_profit,
      status: status,
      duration_hours: duration_hours,
      confidence: confidence,
      risk_reward_ratio: risk_reward_ratio,
      risk_amount: risk_amount,
      reward_amount: reward_amount
    }
  end

  private

  def update_duration
    return unless entry_time

    self.duration_minutes = duration_minutes
  end

  def update_current_pnl
    return unless current_price && entry_price

    self.current_pnl = calculate_current_pnl(current_price)
  end

  def update_max_pnl_tracking
    return unless current_pnl

    if current_pnl > max_profit
      self.max_profit = current_pnl
    end

    if current_pnl < max_loss
      self.max_loss = current_pnl
    end
  end
end
