# frozen_string_literal: true

module Autopilot
  class Manager < ApplicationService
    def initialize
      @agent_client = AgentClient.new
      @running = false
      @thread = nil
    end

    def start
      return false if @running

      Rails.logger.info('[Autopilot::Manager] Starting autopilot...')

      # Check if agent is available
      unless @agent_client.health_check
        Rails.logger.error("[Autopilot::Manager] LLM agent not available at #{ENV.fetch('AGENT_URL', nil)}")
        return false
      end

      @running = true
      @thread = Thread.new { run_autopilot_loop }

      Rails.logger.info("[Autopilot::Manager] Autopilot started in #{mode} mode")
      true
    rescue StandardError => e
      Rails.logger.error("[Autopilot::Manager] Failed to start: #{e.message}")
      false
    end

    def stop! # rubocop:disable Naming/PredicateMethod
      return false unless @running

      Rails.logger.info('[Autopilot::Manager] Stopping autopilot...')

      @running = false
      @thread&.join(5) # Wait up to 5 seconds for graceful shutdown

      Rails.logger.info('[Autopilot::Manager] Autopilot stopped')
      true
    end

    def running?
      @running
    end

    def status
      {
        running: @running,
        mode: mode,
        agent_available: @agent_client.health_check,
        agent_url: ENV.fetch('AGENT_URL', nil)
      }
    end

    private

    def run_autopilot_loop
      Rails.logger.info('[Autopilot::Manager] Autopilot loop started')

      while @running
        begin
          # This is where you would integrate with your signal generation
          # For now, we'll just check agent health periodically
          check_agent_health

          # Sleep for a bit before next check
          sleep(30) # Check every 30 seconds
        rescue StandardError => e
          Rails.logger.error("[Autopilot::Manager] Loop error: #{e.message}")
          sleep(10) # Shorter sleep on error
        end
      end

      Rails.logger.info('[Autopilot::Manager] Autopilot loop ended')
    end

    def check_agent_health
      return if @agent_client.health_check

      Rails.logger.warn('[Autopilot::Manager] Agent health check failed')
    end

    def mode
      if paper_mode?
        'PAPER'
      elsif live_mode?
        'LIVE'
      else
        'DISABLED'
      end
    end

    def paper_mode?
      ActiveModel::Type::Boolean.new.cast(ENV.fetch('PAPER_MODE', nil))
    end

    def live_mode?
      ActiveModel::Type::Boolean.new.cast(ENV.fetch('EXECUTE_ORDERS', nil))
    end
  end
end
