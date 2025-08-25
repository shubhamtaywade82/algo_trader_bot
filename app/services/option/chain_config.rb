# frozen_string_literal: true

module Option
  class ChainConfig
    class << self
      def current = new

      # ------------- gates -------------
      def iv_rank_min        = Setting.fetch_f('opt.iv_rank_min', 0.00)
      def iv_rank_max        = Setting.fetch_f('opt.iv_rank_max', 0.80)
      def theta_avoid_hour   = Setting.fetch_f('opt.theta_avoid_hour', 14.5) # 2:30pm
      def min_adx            = Setting.fetch_f('opt.min_adx', 25.0)

      # ------------- ranking -----------
      def top_ranked_limit   = Setting.fetch_i('opt.top_ranked_limit', 10)
      def efficiency_weight  = Setting.fetch_f('opt.efficiency_weight', 30.0)

      # ------------- Δ thresholds by hour -----------
      # Hours are 24h integer keys; value = min |Δ|
      def min_delta_by_hour
        json = Setting.fetch('opt.min_delta_by_hour_json', nil)
        (json ? JSON.parse(json) : { '11' => 0.30, '13' => 0.35, '14' => 0.45, 'else' => 0.25 })
          .transform_keys!(&:to_s)
      rescue StandardError
        { '11' => 0.30, '13' => 0.35, '14' => 0.45, 'else' => 0.25 }
      end

      # ------------- ATM band by IV rank -----------
      # Each tuple: [max_iv_rank, pct_band]
      def atm_bands
        json = Setting.fetch('opt.atm_bands_json', nil)
        json ? JSON.parse(json) : [[0.20, 0.010], [0.50, 0.015], [1.00, 0.025]]
      rescue StandardError
        [[0.20, 0.010], [0.50, 0.015], [1.00, 0.025]]
      end

      # ------------- scoring knobs -----------
      def lw_intraday = Setting.fetch_f('opt.liquidity_weight_intraday', 0.35)
      def mw_intraday = Setting.fetch_f('opt.momentum_weight_intraday', 0.35)
      def gw_intraday = Setting.fetch_f('opt.greeks_weight_intraday',   0.30)

      def lw_swing    = Setting.fetch_f('opt.liquidity_weight_swing',   0.25)
      def mw_swing    = Setting.fetch_f('opt.momentum_weight_swing',    0.25)
      def gw_swing    = Setting.fetch_f('opt.greeks_weight_swing',      0.50)

      def theta_weight_before_13 = Setting.fetch_f('opt.theta_weight_before_13', 3.0)
      def theta_weight_after_13  = Setting.fetch_f('opt.theta_weight_after_13',  4.0)
      def theta_penalty_days     = Setting.fetch_i('opt.theta_penalty_days', 3)
      def theta_penalty_mult     = Setting.fetch_f('opt.theta_penalty_mult', 2.0)

      def momentum_strong_boost  = Setting.fetch_f('opt.momentum_strong_boost', 1.15)

      # IV skew / z‑score adjustments
      def zscore_penalize_above  = Setting.fetch_f('opt.zscore_penalize_above', 1.5)
      def zscore_factor          = Setting.fetch_f('opt.zscore_factor', 0.90)
      def skew_tilt_boost        = Setting.fetch_f('opt.skew_tilt_boost', 1.10)

      # IV vs HV sanity
      def iv_hv_ratio_cap        = Setting.fetch_f('opt.iv_hv_ratio_cap', 1.5)
      def iv_hv_ratio_factor     = Setting.fetch_f('opt.iv_hv_ratio_factor', 0.90)

      # Misc
      def atm_window_strikes     = Setting.fetch_i('opt.atm_window_strikes', 3)
    end
  end
end
