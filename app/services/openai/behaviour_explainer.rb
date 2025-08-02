module Openai
  class BehaviourExplainer < ApplicationService
    def initialize(analysis_hash)
      @data = analysis_hash
    end

    def call
      prompt = build_prompt
      typing_ping
      completion = OpenAI::Client.new.chat(
        parameters: {
          model: 'gpt-4',
          messages: [
            { role: 'system', content: 'You are an options trading expert' },
            { role: 'user', content: prompt }
          ],
          temperature: 0.7
        }
      )
      result = completion.dig('choices', 0, 'message', 'content')
      notify("📘 AI Options Insight for #{@data[:symbol]}:\n\n#{result}", tag: 'AI_EXPLAIN')
      result
    rescue StandardError => e
      notify_failure(e, :openai)
      nil
    end

    def build_prompt
      <<~PROMPT
        Given the following ATM options data for #{@data[:symbol]} (#{@data[:expiry]}), analyze the market sentiment and expected move direction:

        CE:
        • Price: #{@data[:ce][:last_price]}
        • IV: #{@data[:ce][:iv]}
        • Δ: #{@data[:ce][:delta]}
        • θ: #{@data[:ce][:theta]}
        • OI: #{@data[:ce][:oi]}
        • Price Change: #{@data[:ce][:price_change]}

        PE:
        • Price: #{@data[:pe][:last_price]}
        • IV: #{@data[:pe][:iv]}
        • Δ: #{@data[:pe][:delta]}
        • θ: #{@data[:pe][:theta]}
        • OI: #{@data[:pe][:oi]}
        • Price Change: #{@data[:pe][:price_change]}

        Spot: #{@data[:spot]}
        ATM: #{@data[:atm]}

        Respond with:
        - Sentiment: Bullish / Bearish / Neutral
        - Reasoning
        - Suggested next move for CE or PE buying (if any)
      PROMPT
    end
  end
end