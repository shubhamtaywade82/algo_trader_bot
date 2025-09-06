# frozen_string_literal: true

module Execution
  # Immutable bag of tunables for exit logic; sourced from ENV with safe defaults.
  class RiskPolicy
    attr_reader :sl_pct, :tp_pct, :trail_jump_pct, :breakeven_at_pct,
                :lock_step_pct, :stale_win_min_gain_pct, :stale_secs

    def self.load
      new(
        sl_pct: ENV.fetch('RISK_SL_PCT', '0.05').to_f,
        tp_pct: ENV.fetch('RISK_TP_PCT', '0.20').to_f,
        trail_jump_pct: ENV.fetch('RISK_TRAIL_JUMP_PCT', '0.03').to_f,
        breakeven_at_pct: ENV.fetch('RISK_BREAKEVEN_AT_PCT', '0.05').to_f,
        lock_step_pct: ENV.fetch('RISK_LOCK_STEP_PCT', '0.02').to_f,
        stale_win_min_gain_pct: ENV.fetch('STALE_WIN_MIN_GAIN_PCT', '0.10').to_f,
        stale_secs: ENV.fetch('STALE_SECS', '120').to_i
      )
    end

    def initialize(**h)
      @sl_pct                 = h.fetch(:sl_pct)
      @tp_pct                 = h.fetch(:tp_pct)
      @trail_jump_pct         = h.fetch(:trail_jump_pct)
      @breakeven_at_pct       = h.fetch(:breakeven_at_pct)
      @lock_step_pct          = h.fetch(:lock_step_pct)
      @stale_win_min_gain_pct = h.fetch(:stale_win_min_gain_pct)
      @stale_secs             = h.fetch(:stale_secs)
      freeze
    end
  end
end
