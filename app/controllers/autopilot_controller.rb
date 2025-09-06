# frozen_string_literal: true

class AutopilotController < ApplicationController
  # GET /autopilot/status
  def status
    render json: {
      status: 'success',
      data: {
        running: false, # Simplified for now
        mode: paper_mode? ? 'paper' : 'live',
        agent_url: ENV.fetch('AGENT_URL', nil)
      }
    }
  end

  # POST /autopilot/start
  def start
    render json: {
      status: 'success',
      message: 'Autopilot start requested (simplified mode)',
      data: {
        running: true,
        mode: paper_mode? ? 'paper' : 'live',
        agent_url: ENV.fetch('AGENT_URL', nil)
      }
    }
  end

  # POST /autopilot/stop
  def stop
    render json: {
      status: 'success',
      message: 'Autopilot stop requested (simplified mode)',
      data: {
        running: false,
        mode: paper_mode? ? 'paper' : 'live',
        agent_url: ENV.fetch('AGENT_URL', nil)
      }
    }
  end

  # POST /autopilot/signal
  def send_signal
    signal_data = params.expect(
      signal: %i[symbol spot supertrend_15m adx_15m iv_percentile session_time]
    ).to_h

    processor = Autopilot::SignalProcessor.new(signal_data)

    if processor.call
      render json: {
        status: 'success',
        message: 'Signal processed successfully',
        data: { signal: signal_data, mode: paper_mode? ? 'PAPER' : 'LIVE' }
      }
    else
      render json: {
        status: 'error',
        message: 'Failed to process signal'
      }, status: :internal_server_error
    end
  end

  # GET /autopilot/agent_health
  def agent_health
    client = Autopilot::AgentClient.new

    if client.health_check
      render json: {
        status: 'success',
        message: 'Agent is healthy',
        data: { agent_url: ENV.fetch('AGENT_URL', nil) }
      }
    else
      render json: {
        status: 'error',
        message: 'Agent is not responding',
        data: { agent_url: ENV.fetch('AGENT_URL', nil) }
      }, status: :service_unavailable
    end
  end

  private

  def paper_mode?
    ActiveModel::Type::Boolean.new.cast(ENV.fetch('PAPER_MODE', nil))
  end
end
