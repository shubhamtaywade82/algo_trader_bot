# frozen_string_literal: true

# Trading controller for managing the trading engine and positions
class TradingController < ApplicationController
  before_action :set_trading_engine
  before_action :set_cors_headers

  # GET /trading/status
  def status
    render json: {
      success: true,
      data: {
        engine: @trading_engine.status,
        signal_generator: @trading_engine.signal_generator.signal_stats,
        signal_processor: @trading_engine.signal_processor.stats,
        position_manager: @trading_engine.position_manager.stats
      }
    }
  end

  # POST /trading/start
  def start
    if @trading_engine.running?
      render json: { success: false, error: 'Trading engine is already running' }
      return
    end

    if @trading_engine.start!
      render json: {
        success: true,
        message: 'Trading engine started successfully',
        status: @trading_engine.status
      }
    else
      render json: { success: false, error: 'Failed to start trading engine' }
    end
  end

  # POST /trading/stop
  def stop
    unless @trading_engine.running?
      render json: { success: false, error: 'Trading engine is not running' }
      return
    end

    if @trading_engine.stop!
      render json: {
        success: true,
        message: 'Trading engine stopped successfully',
        status: @trading_engine.status
      }
    else
      render json: { success: false, error: 'Failed to stop trading engine' }
    end
  end

  # GET /trading/positions
  def positions
    positions = @trading_engine.position_manager.active_positions
    position_stats = @trading_engine.position_manager.all_position_stats

    render json: {
      success: true,
      data: {
        positions: positions.map { |p| position_to_json(p) },
        stats: position_stats,
        portfolio: @trading_engine.position_manager.portfolio_stats
      }
    }
  end

  # GET /trading/positions/:id
  def show_position
    position = @trading_engine.position_manager.get_position(params[:id])

    if position
      stats = @trading_engine.position_manager.position_stats(params[:id])
      render json: {
        success: true,
        data: {
          position: position_to_json(position),
          stats: stats
        }
      }
    else
      render json: { success: false, error: 'Position not found' }
    end
  end

  # POST /trading/positions/:id/close
  def close_position
    position = @trading_engine.position_manager.get_position(params[:id])

    unless position
      render json: { success: false, error: 'Position not found' }
      return
    end

    # Create exit signal
    exit_signal = {
      id: SecureRandom.uuid,
      position_id: position.id,
      instrument: position.instrument,
      strategy: position.strategy,
      side: position.side,
      quantity: position.quantity,
      current_price: position.instrument.ltp,
      current_pnl: calculate_current_pnl(position),
      reason: 'manual_close',
      created_at: Time.current,
      type: 'exit'
    }

    # Process exit signal
    result = @trading_engine.signal_processor.process_exit_signal(exit_signal)

    if result[:success]
      render json: {
        success: true,
        message: 'Position closed successfully',
        data: result
      }
    else
      render json: {
        success: false,
        error: result[:reason] || 'Failed to close position'
      }
    end
  end

  # POST /trading/close_all
  def close_all_positions
    unless @trading_engine.running?
      render json: { success: false, error: 'Trading engine is not running' }
      return
    end

    closed_count = @trading_engine.position_manager.close_all_positions!

    render json: {
      success: true,
      message: "Closed #{closed_count} positions",
      closed_count: closed_count
    }
  end

  # GET /trading/signals
  def signals
    # Get recent signals (this would need to be implemented in the signal generator)
    render json: {
      success: true,
      data: {
        queued_signals: @trading_engine.signal_processor.stats[:queued_signals],
        message: 'Signal history not yet implemented'
      }
    }
  end

  # POST /trading/process_signals
  def process_signals
    if @trading_engine.process_pending_signals!
      render json: {
        success: true,
        message: 'Pending signals processed successfully'
      }
    else
      render json: {
        success: false,
        error: 'Failed to process pending signals'
      }
    end
  end

  # GET /trading/stats
  def stats
    render json: {
      success: true,
      data: @trading_engine.trading_stats
    }
  end

  # GET /trading/health
  def health
    engine_healthy = @trading_engine.running? &&
                    @trading_engine.status[:error_count] < 5 &&
                    !@trading_engine.position_manager.daily_loss_limit_reached?

    render json: {
      success: true,
      data: {
        healthy: engine_healthy,
        engine_running: @trading_engine.running?,
        error_count: @trading_engine.status[:error_count],
        daily_loss_limit_reached: @trading_engine.position_manager.daily_loss_limit_reached?,
        active_positions: @trading_engine.position_manager.active_positions.count,
        last_update: @trading_engine.status[:last_update]
      }
    }
  end

  private

  def set_trading_engine
    @trading_engine ||= Trading::Engine.new
  end

  def set_cors_headers
    headers['Access-Control-Allow-Origin'] = '*'
    headers['Access-Control-Allow-Methods'] = 'GET, POST, PUT, DELETE, OPTIONS'
    headers['Access-Control-Allow-Headers'] = 'Content-Type, Authorization'
  end

  def position_to_json(position)
    {
      id: position.id,
      instrument: {
        id: position.instrument.id,
        symbol: position.instrument.symbol,
        name: position.instrument.name,
        ltp: position.instrument.ltp
      },
      side: position.side,
      quantity: position.quantity,
      entry_price: position.entry_price,
      stop_loss: position.stop_loss,
      take_profit: position.take_profit,
      strategy: position.strategy,
      confidence: position.confidence,
      risk_reward_ratio: position.risk_reward_ratio,
      expected_profit: position.expected_profit,
      expected_loss: position.expected_loss,
      status: position.status,
      current_pnl: calculate_current_pnl(position),
      created_at: position.created_at,
      updated_at: position.updated_at
    }
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
end
