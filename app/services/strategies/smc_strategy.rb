# frozen_string_literal: true

module Strategies
  class SMCStrategy < ApplicationService
    def initialize(series:)
      @series = series
      @score = 0
      @reasons = []
    end

    def call
      return hold_signal("Not enough candles") if series.size < 50

      # Run all SMC indicators
      bos     = SMC::Bos.call(series: series)
      choch   = SMC::Choch.call(series: series)
      order_blocks = SMC::OrderBlock.call(series: series)
      fvg     = SMC::FairValueGap.call(series: series)
      mitg    = SMC::Mitigation.call(series: series)
      induc   = SMC::Inducement.call(series: series)
      grab_up = series.liquidity_grab_up?
      grab_dn = series.liquidity_grab_down?

      # Scoring
      apply_score(:bos, bos)
      apply_score(:choch, choch)
      apply_score(:order_block, order_blocks)
      apply_score(:fvg, fvg)
      apply_score(:mitigation, mitg)
      apply_score(:inducement, induc)
      apply_score(:liquidity_grab_up, grab_up)
      apply_score(:liquidity_grab_down, grab_dn)

      confidence = score

      if confidence >= 70 && (bos || choch)
        action = grab_up ? :buy_pe : grab_dn ? :buy_ce : :hold
        build_signal(action, confidence)
      else
        hold_signal("Low SMC confidence: #{confidence}%")
      end
    rescue => e
      notify_failure(e, "SMCStrategy")
      hold_signal("Exception: #{e.message}")
    end

    private

    attr_reader :series, :score, :reasons

    def apply_score(name, result)
      return unless result

      weight = case name
               when :bos then 20
               when :choch then 15
               when :order_block then 10
               when :fvg then 10
               when :mitigation then 10
               when :inducement then 10
               when :liquidity_grab_up, :liquidity_grab_down then 15
               else 0
               end

      @score += weight
      reasons << "#{name.to_s.titleize} = TRUE (+#{weight})"
    end

    def build_signal(action, confidence)
      {
        strategy: :smc,
        action: action,
        confidence: confidence,
        reasons: reasons,
        stop_loss: derive_sl(action),
        take_profit: derive_tp(action)
      }
    end

    def derive_sl(action)
      atr = Indicators::AtrBand.call(series: series)
      last = series.last
      action == :buy_ce ? last.low - atr : last.high + atr
    end

    def derive_tp(action)
      atr = Indicators::AtrBand.call(series: series)
      last = series.last
      action == :buy_ce ? last.close + 3 * atr : last.close - 3 * atr
    end

    def hold_signal(reason)
      {
        strategy: :smc,
        action: :hold,
        confidence: score,
        reasons: reasons << reason
      }
    end
  end
end
