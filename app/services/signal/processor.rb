# frozen_string_literal: true

# Signal processor that handles signal execution and position management
# Integrates with risk management and order execution
class Signal::Processor
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :risk_guard, default: -> { Risk::Guard.new }
  attribute :order_executor, default: -> { Orders::Executor.new }
  attribute :position_guard, default: -> { Execution::PositionGuard.new }
  attribute :max_concurrent_positions, :integer, default: 5
  attribute :signal_timeout, :integer, default: 30 # seconds

  def initialize(attributes = {})
    super
    @active_positions = {}
    @signal_queue = []
    @processing = false
  end

  # Process entry signals
  def process_entry_signals(signals)
    return [] if signals.empty?

    results = []
    signals.each do |signal|
      next unless signal[:type] == 'entry'

      begin
        result = process_entry_signal(signal)
        results << result if result
      rescue StandardError => e
        Rails.logger.error "Entry signal processing failed: #{e.message}"
        results << { signal: signal, success: false, error: e.message }
      end
    end

    results
  end

  # Process exit signals
  def process_exit_signals(signals)
    return [] if signals.empty?

    results = []
    signals.each do |signal|
      next unless signal[:type] == 'exit'

      begin
        result = process_exit_signal(signal)
        results << result if result
      rescue StandardError => e
        Rails.logger.error "Exit signal processing failed: #{e.message}"
        results << { signal: signal, success: false, error: e.message }
      end
    end

    results
  end

  # Process a single entry signal
  def process_entry_signal(signal)
    instrument = signal[:instrument]

    # Check if we already have a position for this instrument
    return { signal: signal, success: false, reason: 'position_exists' } if position_exists?(instrument)

    # Check risk management
    unless risk_guard.allow_entry?(
      expected_risk_rupees: signal[:expected_loss],
      seg: instrument.exchange_segment,
      sid: instrument.symbol_id
    )
      return { signal: signal, success: false, reason: 'risk_guard_blocked' }
    end

    # Check position limits
    if active_position_count >= max_concurrent_positions
      return { signal: signal, success: false, reason: 'max_positions_reached' }
    end

    # Execute the order
    order_result = execute_entry_order(signal)
    return { signal: signal, success: false, reason: 'order_execution_failed', error: order_result[:error] } unless order_result[:success]

    # Create position record
    position = create_position(signal, order_result)
    return { signal: signal, success: false, reason: 'position_creation_failed' } unless position

    # Update active positions
    @active_positions[instrument.id] = position

    {
      signal: signal,
      success: true,
      position: position,
      order: order_result[:order]
    }
  end

  # Process a single exit signal
  def process_exit_signal(signal)
    position = find_position(signal[:position_id])
    return { signal: signal, success: false, reason: 'position_not_found' } unless position

    # Execute exit order
    order_result = execute_exit_order(signal, position)
    return { signal: signal, success: false, reason: 'order_execution_failed', error: order_result[:error] } unless order_result[:success]

    # Update position status
    position.update!(
      status: 'closed',
      exit_price: signal[:current_price],
      exit_reason: signal[:reason],
      closed_at: Time.current,
      final_pnl: signal[:current_pnl]
    )

    # Remove from active positions
    @active_positions.delete(position.instrument.id)

    {
      signal: signal,
      success: true,
      position: position,
      order: order_result[:order]
    }
  end

  # Get current positions
  def active_positions
    @active_positions.values
  end

  # Get position count
  def active_position_count
    @active_positions.size
  end

  # Check if position exists for instrument
  def position_exists?(instrument)
    @active_positions.key?(instrument.id)
  end

  # Find position by ID
  def find_position(position_id)
    @active_positions.values.find { |p| p.id == position_id }
  end

  # Process all pending signals
  def process_pending_signals
    return if @processing

    @processing = true
    begin
      # Process entry signals
      entry_signals = @signal_queue.select { |s| s[:type] == 'entry' }
      process_entry_signals(entry_signals)

      # Process exit signals
      exit_signals = @signal_queue.select { |s| s[:type] == 'exit' }
      process_exit_signals(exit_signals)

      # Clear processed signals
      @signal_queue.clear
    ensure
      @processing = false
    end
  end

  # Add signal to queue
  def queue_signal(signal)
    @signal_queue << signal
  end

  # Get processor statistics
  def stats
    {
      active_positions: active_position_count,
      queued_signals: @signal_queue.size,
      processing: @processing,
      max_positions: max_concurrent_positions
    }
  end

  private

  def execute_entry_order(signal)
    instrument = signal[:instrument]

    # Build order parameters
    order_params = {
      instrument: instrument,
      side: signal[:side],
      quantity: signal[:quantity],
      entry_price: signal[:entry_price],
      stop_loss: signal[:stop_loss],
      take_profit: signal[:take_profit],
      strategy: signal[:strategy],
      client_ref: generate_client_ref(signal)
    }

    # Execute order
    order_executor.execute(order_params)
  end

  def execute_exit_order(signal, position)
    # Build exit order parameters
    order_params = {
      position: position,
      quantity: signal[:quantity],
      exit_price: signal[:current_price],
      reason: signal[:reason]
    }

    # Execute exit order
    order_executor.exit_position(order_params)
  end

  def create_position(signal, order_result)
    Position.create!(
      instrument: signal[:instrument],
      side: signal[:side],
      quantity: signal[:quantity],
      entry_price: signal[:entry_price],
      stop_loss: signal[:stop_loss],
      take_profit: signal[:take_profit],
      strategy: signal[:strategy],
      confidence: signal[:confidence],
      risk_reward_ratio: signal[:risk_reward_ratio],
      expected_profit: signal[:expected_profit],
      expected_loss: signal[:expected_loss],
      order_id: order_result[:order]&.id,
      status: 'active',
      created_at: Time.current
    )
  rescue StandardError => e
    Rails.logger.error "Position creation failed: #{e.message}"
    nil
  end

  def generate_client_ref(signal)
    timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
    strategy_short = signal[:strategy].gsub('Strategy::', '').downcase
    "#{strategy_short}_#{signal[:instrument].symbol}_#{timestamp}"
  end

  def validate_signal(signal)
    return false unless signal.present?
    return false unless signal[:instrument].present?
    return false unless signal[:side].present?
    return false unless signal[:quantity].present? && signal[:quantity] > 0
    return false unless signal[:entry_price].present? && signal[:entry_price] > 0

    true
  end

  def log_signal_processing(signal, result)
    Rails.logger.info "Signal processed: #{signal[:strategy]} - #{signal[:side]} #{signal[:quantity]} #{signal[:instrument].symbol} - #{result[:success] ? 'SUCCESS' : 'FAILED'}"

    unless result[:success]
      Rails.logger.warn "Signal processing failed: #{result[:reason]} - #{result[:error]}"
    end
  end
end
