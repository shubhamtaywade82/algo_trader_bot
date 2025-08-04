# frozen_string_literal: true

module Strategies
  class HolyGrailStrategy < BaseIndicatorStrategy
    STRATEGIES = {
      rsi_adx: Strategies::RsiAdxCombo,
      macd_supertrend: Strategies::MacdSupertrend,
      bollinger_rsi: Strategies::BollingerRsi,
      donchian_adx: Strategies::DonchianAdx
      # vwap_rsi: Strategies::VwapRsi,
      # obv_macd: Strategies::ObvMacd
    }.freeze

    STRATEGY_WEIGHTS = {
      rsi_adx: 0.15,
      macd_supertrend: 0.2,
      bollinger_rsi: 0.15,
      donchian_adx: 0.15
      # vwap_rsi: 0.15,
      # obv_macd: 0.2
    }.freeze

    def initialize(instrument, series: nil)
      @instrument = instrument
      @series = series || instrument.candles('5')
    end

    def call
      results = run_all_strategies

      top_signal = results[:votes].max_by { |_signal, w| w }&.first || :hold
      final_score = results[:score]

      {
        strategy: :holygrail,
        instrument: instrument.symbol,
        action: top_signal,
        confidence: final_score.round(2),
        reasons: results[:reasons],
        telemetry: results[:telemetry],
        decision: final_score >= 0.65 ? top_signal : :hold
      }
    end

    # ✨ AI Prompt Payload: use this output to pass to OpenAI
    def ai_prompt_payload
      result = call
      <<~PROMPT.strip
        Instrument: #{result[:instrument]}
        Final Action: #{result[:action].to_s.upcase}
        Confidence Score: #{result[:confidence]}%
        Decision Reasoning:
        #{result[:reasons].map { |r| "- #{r}" }.join("\n")}

        Indicator Telemetry:
        #{result[:telemetry].map { |k, v| "#{k.to_s.titleize}: #{v}" }.join("\n")}

        Based on the above, analyze the current market structure, probable support/resistance zones, and possible close for today. If market is closed, prepare analysis for next session. Suggest any CE/PE trade or HOLD decision with SL/TP levels.
      PROMPT
    end

    private

    attr_reader :instrument, :series

    def run_all_strategies
      results = {
        score: 0.0,
        votes: Hash.new(0),
        reasons: [],
        telemetry: {}
      }

      STRATEGIES.each do |key, klass|
        strat = klass.new(instrument, series: series)
        outcome = strat.signal_details

        next unless outcome

        weight = STRATEGY_WEIGHTS[key]
        results[:votes][outcome[:signal]] += weight
        results[:score] += outcome[:confidence] * weight
        results[:reasons] << "#{key.to_s.titleize} → #{outcome[:signal].to_s.upcase} (#{(outcome[:confidence] * weight).round(1)} pts)"
        results[:telemetry][key] = outcome[:reason]
      end

      results
    end
  end
end