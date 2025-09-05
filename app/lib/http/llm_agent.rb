# frozen_string_literal: true

require 'faraday'
require 'faraday/retry'
require 'json'

module Http
  class LlmAgent
    class << self
      def conn
        @conn ||= Faraday.new(url: ENV.fetch('LLM_AGENT_URL')) do |f|
          f.request :json
          f.response :json, content_type: /\bjson$/
          f.request :retry, max: 2, interval: 0.3, backoff_factor: 2.0,
                            retry_statuses: [408, 429, 500, 502, 503, 504]
          f.options.timeout      = ENV.fetch('LLM_AGENT_TIMEOUT', 20).to_i
          f.options.open_timeout = 5
          f.adapter Faraday.default_adapter
        end
      end

      # POST /signal on the Agent; returns the LLM "plan" JSON
      def propose_plan!(context:, user: nil)
        headers = {}
        headers['X-LLM-AGENT-KEY'] = ENV['LLM_AGENT_KEY'] if ENV['LLM_AGENT_KEY'].present?
        res = conn.post('/signal', { context: context, user: user }, headers)
        raise "LLM agent HTTP #{res.status}: #{res.body}" unless res.success?
        body = res.body.is_a?(String) ? JSON.parse(res.body) : res.body
        body.fetch('plan')
      end
    end
  end
end
