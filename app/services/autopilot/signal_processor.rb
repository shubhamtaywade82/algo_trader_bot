# frozen_string_literal: true

module Autopilot
  class SignalProcessor < ApplicationService
    def initialize(signal_data)
      @signal_data = signal_data
      @agent_client = AgentClient.new
    end

    def call
      return false unless validate_signal
      return false unless agent_available?

      # Send signal to LLM agent
      plan = @agent_client.send_signal(@signal_data)
      return false unless plan

      # Execute the plan if we're in live mode
      if live_mode?
        execute_plan(plan)
      else
        log_paper_mode(plan)
      end

      true
    rescue StandardError => e
      Rails.logger.error("[Autopilot::SignalProcessor] Error: #{e.message}")
      false
    end

    private

    def validate_signal! # rubocop:disable Naming/PredicateMethod
      required_keys = %w[symbol spot supertrend_15m adx_15m iv_percentile session_time]
      missing_keys = required_keys - @signal_data.keys.map(&:to_s)

      if missing_keys.any?
        Rails.logger.error("[Autopilot::SignalProcessor] Missing signal keys: #{missing_keys}")
        return false
      end

      true
    end

    def agent_available?
      unless @agent_client.health_check
        Rails.logger.error('[Autopilot::SignalProcessor] LLM agent not available')
        return false
      end
      true
    end

    def live_mode?
      !paper_mode?
    end

    def paper_mode?
      ActiveModel::Type::Boolean.new.cast(ENV.fetch('PAPER_MODE', nil))
    end

    def execute_plan(plan)
      Rails.logger.info("[Autopilot::SignalProcessor] Executing plan in live mode: #{plan}")

      # Execute the plan through the agent
      result = @agent_client.execute_plan(plan)

      if result
        Rails.logger.info("[Autopilot::SignalProcessor] Plan executed successfully: #{result}")
        notify_execution(result)
      else
        Rails.logger.error('[Autopilot::SignalProcessor] Plan execution failed')
      end

      result
    end

    def log_paper_mode(plan)
      Rails.logger.info('[Autopilot::SignalProcessor] PAPER MODE - Plan would be executed:')
      Rails.logger.info("[Autopilot::SignalProcessor] Plan: #{JSON.pretty_generate(plan)}")

      # Log to a paper trading log file
      log_paper_trade(plan)

      # Notify about paper mode execution
      notify_paper_mode(plan)
    end

    def log_paper_trade(plan)
      log_entry = {
        timestamp: Time.current.iso8601,
        mode: 'PAPER',
        signal: @signal_data,
        plan: plan
      }

      Rails.logger.info("[PAPER_TRADE] #{log_entry.to_json}")
    end

    def notify_execution(result)
      # Add your notification logic here (Telegram, email, etc.)
      Rails.logger.info("[Autopilot::SignalProcessor] Trade executed: #{result}")
    end

    def notify_paper_mode(plan)
      # Add your paper mode notification logic here
      Rails.logger.info("[Autopilot::SignalProcessor] Paper trade simulated: #{plan}")
    end
  end
end
