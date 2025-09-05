# frozen_string_literal: true

module Llm
  class SignalService
    def self.propose(symbol:, trend:, adx:, ivp:)
      return nil if ENV['LLM_MODE'] == 'off'

      context = {
        symbol: symbol,
        spot:   Market::SpotFetcher.call(symbol: symbol),
        supertrend_15m: trend.to_s,
        adx_15m:        adx.to_f,
        iv_percentile:  ivp.to_f,
        session_time:   Time.zone.now.strftime('%H:%M')
      }

      user = 'Strict liquidity; next_week; 30/60; BE@+15%; trail 2.'
      Http::LlmAgent.propose_plan!(context: context, user: user)
    end
  end
end
