module SMC
  class Interpreter < ApplicationService
    def initialize(analysis_hash)
      @analysis = analysis_hash
    end

    def call
      client = OpenAI::Client.new(...)
      prompt = build_prompt
      response = client.chat(... prompt ...)
      JSON.parse(response.dig("choices", 0, "message", "content"))
    end

    def build_prompt
      openai_prompt_for_smc(@analysis)
    end
  end
end
