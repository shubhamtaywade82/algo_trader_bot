# frozen_string_literal: true

module Autopilot
  class AgentClient < ApplicationService
    def initialize
      @agent_url = ENV['AGENT_URL'] || 'http://172.20.240.1:3001'
      @timeout = 30.seconds
    end

    # Send signal to LLM agent and get trading plan
    def send_signal(signal_data)
      Rails.logger.info("[Autopilot::AgentClient] Sending signal to agent: #{signal_data.inspect}")

      response = make_request('POST', '/signal', signal_data)

      if response[:success]
        Rails.logger.info("[Autopilot::AgentClient] Received plan from agent: #{response[:data]}")
        response[:data]
      else
        Rails.logger.error("[Autopilot::AgentClient] Agent error: #{response[:error]}")
        nil
      end
    rescue StandardError => e
      Rails.logger.error("[Autopilot::AgentClient] Connection error: #{e.message}")
      nil
    end

    # Execute trading plan from agent
    def execute_plan(plan_data)
      Rails.logger.info("[Autopilot::AgentClient] Executing plan: #{plan_data.inspect}")

      response = make_request('POST', '/execute', plan_data)

      if response[:success]
        Rails.logger.info("[Autopilot::AgentClient] Plan executed: #{response[:data]}")
        response[:data]
      else
        Rails.logger.error("[Autopilot::AgentClient] Execution error: #{response[:error]}")
        nil
      end
    rescue StandardError => e
      Rails.logger.error("[Autopilot::AgentClient] Execution error: #{e.message}")
      nil
    end

    # Check if agent is available
    def health_check
      response = make_request('GET', '/health')
      response[:success]
    rescue StandardError => e
      Rails.logger.error("[Autopilot::AgentClient] Health check failed: #{e.message}")
      false
    end

    private

    def make_request(method, path, body = nil)
      uri = URI("#{@agent_url}#{path}")

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == 'https'
      http.read_timeout = @timeout
      http.open_timeout = @timeout

      case method.upcase
      when 'GET'
        request = Net::HTTP::Get.new(uri)
      when 'POST'
        request = Net::HTTP::Post.new(uri)
        request['Content-Type'] = 'application/json'
        request.body = body.to_json if body
      else
        raise ArgumentError, "Unsupported HTTP method: #{method}"
      end

      response = http.request(request)

      if response.code.to_i.between?(200, 299)
        data = JSON.parse(response.body, symbolize_names: true)
        { success: true, data: data }
      else
        { success: false, error: "HTTP #{response.code}: #{response.body}" }
      end
    rescue JSON::ParserError => e
      { success: false, error: "JSON parse error: #{e.message}" }
    rescue StandardError => e
      { success: false, error: e.message }
    end
  end
end
