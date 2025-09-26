# frozen_string_literal: true

# Position exit manager for handling various exit strategies
class Position::ExitManager
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :order_executor, default: -> { Orders::Executor.new }
  attribute :exit_strategies, default: -> { default_exit_strategies }
  attribute :max_exit_attempts, :integer, default: 3
  attribute :exit_timeout, :integer, default: 30 # seconds

  def initialize(attributes = {})
    super
    @exit_queue = []
    @processing = false
  end

  # Process exit for a position
  def process_exit(position, reason, exit_price = nil)
    return false unless position&.active?

    exit_price ||= get_current_exit_price(position)
    return false unless exit_price

    exit_request = build_exit_request(position, reason, exit_price)

    # Validate exit request
    return false unless valid_exit_request?(exit_request)

    # Add to exit queue
    @exit_queue << exit_request

    # Process immediately if not already processing
    process_exit_queue unless @processing

    true
  end

  # Process all pending exits
  def process_exit_queue
    return if @processing || @exit_queue.empty?

    @processing = true

    begin
      while @exit_queue.any?
        exit_request = @exit_queue.shift
        process_single_exit(exit_request)
      end
    ensure
      @processing = false
    end
  end

  # Force exit all positions
  def force_exit_all!(reason = 'system_exit')
    positions = TradingPosition.active
    results = []

    positions.each do |position|
      result = process_exit(position, reason)
      results << { position: position, success: result }
    end

    results
  end

  # Exit positions by strategy
  def exit_by_strategy!(strategy, reason = 'strategy_exit')
    positions = TradingPosition.active.by_strategy(strategy)
    results = []

    positions.each do |position|
      result = process_exit(position, reason)
      results << { position: position, success: result }
    end

    results
  end

  # Exit positions by time
  def exit_by_time!(max_hours, reason = 'time_exit')
    positions = TradingPosition.active.where('entry_time < ?', max_hours.hours.ago)
    results = []

    positions.each do |position|
      result = process_exit(position, reason)
      results << { position: position, success: result }
    end

    results
  end

  # Exit positions by P&L
  def exit_by_pnl!(min_profit, max_loss, reason = 'pnl_exit')
    positions = TradingPosition.active.where(
      'current_pnl >= ? OR current_pnl <= ?',
      min_profit, max_loss
    )
    results = []

    positions.each do |position|
      result = process_exit(position, reason)
      results << { position: position, success: result }
    end

    results
  end

  # Get exit statistics
  def exit_stats
    {
      queued_exits: @exit_queue.length,
      processing: @processing,
      total_exits_today: TradingPosition.closed.today.count,
      exit_reasons: get_exit_reason_stats
    }
  end

  private

  def default_exit_strategies
    {
      stop_loss: { priority: 1, immediate: true },
      take_profit: { priority: 1, immediate: true },
      trailing_stop: { priority: 1, immediate: true },
      time_exit: { priority: 2, immediate: false },
      risk_exit: { priority: 2, immediate: false },
      manual_close: { priority: 3, immediate: true },
      strategy_exit: { priority: 3, immediate: false },
      system_exit: { priority: 0, immediate: true }
    }
  end

  def build_exit_request(position, reason, exit_price)
    {
      position: position,
      reason: reason,
      exit_price: exit_price,
      priority: exit_strategies[reason.to_sym]&.dig(:priority) || 5,
      immediate: exit_strategies[reason.to_sym]&.dig(:immediate) || false,
      created_at: Time.current,
      attempts: 0
    }
  end

  def valid_exit_request?(exit_request)
    position = exit_request[:position]
    return false unless position&.active?

    exit_price = exit_request[:exit_price]
    return false unless exit_price && exit_price > 0

    true
  end

  def process_single_exit(exit_request)
    position = exit_request[:position]
    reason = exit_request[:reason]
    exit_price = exit_request[:exit_price]

    begin
      # Execute exit order
      order_result = execute_exit_order(position, exit_price, reason)

      if order_result[:success]
        # Update position status
        position.close_position!(exit_price, reason)
        Rails.logger.info "Position #{position.id} exited successfully: #{reason}"
      else
        # Retry if not exceeded max attempts
        if exit_request[:attempts] < max_exit_attempts
          exit_request[:attempts] += 1
          @exit_queue << exit_request
          Rails.logger.warn "Exit failed for position #{position.id}, retrying..."
        else
          Rails.logger.error "Max exit attempts exceeded for position #{position.id}"
        end
      end

      order_result
    rescue StandardError => e
      Rails.logger.error "Exit processing error for position #{position.id}: #{e.message}"
      { success: false, error: e.message }
    end
  end

  def execute_exit_order(position, exit_price, reason)
    # Build exit order parameters
    order_params = {
      position: position,
      side: position.side == 'BUY' ? 'SELL' : 'BUY',
      quantity: position.quantity,
      price: exit_price,
      order_type: 'MARKET',
      product_type: 'INTRADAY',
      reason: reason
    }

    # Execute order
    order_executor.exit_position(order_params)
  end

  def get_current_exit_price(position)
    # Try to get current market price
    current_price = position.instrument&.ltp
    return current_price if current_price && current_price > 0

    # Fallback to position's current price
    position.current_price
  end

  def get_exit_reason_stats
    TradingPosition.closed.today
                  .group(:exit_reason)
                  .count
  end

  # Exit strategy implementations

  def stop_loss_exit(position)
    return false unless position.stop_loss

    current_price = position.current_price
    return false unless current_price

    if position.stop_loss_hit?(current_price)
      process_exit(position, 'stop_loss', current_price)
      true
    else
      false
    end
  end

  def take_profit_exit(position)
    return false unless position.take_profit

    current_price = position.current_price
    return false unless current_price

    if position.take_profit_hit?(current_price)
      process_exit(position, 'take_profit', current_price)
      true
    else
      false
    end
  end

  def trailing_stop_exit(position)
    return false unless position.trailing_stop_active?

    current_price = position.current_price
    return false unless current_price

    if position.trailing_stop_hit?(current_price)
      process_exit(position, 'trailing_stop', current_price)
      true
    else
      false
    end
  end

  def time_based_exit(position, max_hours = 4)
    return false if position.duration_hours <= max_hours

    current_price = position.current_price
    process_exit(position, 'time_exit', current_price)
    true
  end

  def risk_based_exit(position, max_risk_multiple = 2.0)
    return false unless position.expected_loss

    current_pnl = position.current_pnl
    max_loss = position.expected_loss * max_risk_multiple

    return false if current_pnl > -max_loss

    current_price = position.current_price
    process_exit(position, 'risk_exit', current_price)
    true
  end

  def profit_target_exit(position, target_multiple = 2.0)
    return false unless position.expected_profit

    current_pnl = position.current_pnl
    target_profit = position.expected_profit * target_multiple

    return false if current_pnl < target_profit

    current_price = position.current_price
    process_exit(position, 'profit_target', current_price)
    true
  end
end
