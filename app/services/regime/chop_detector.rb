# app/services/regime/chop_detector.rb
# Detects sideways/range conditions using lightweight signals from CandleSeries.
module Regime
  class ChopDetector
    # Any 2 true ⇒ choppy
    # cs5/cs15 are CandleSeries instances (5m/15m) you already have.
    def self.choppy_pre_entry?(cs5, _cs15, opts = {})
      adx_th    = (opts[:adx_min] || 18).to_i
      atr_mult  = (opts[:atr_quiet_mult] || 0.8).to_f
      cross_win = (opts[:vwap_cross_window] || 30).to_i

      low_adx   = safe { cs5.adx(14) }&.<(adx_th) || false
      quiet_atr = begin
        atr_now  = safe { cs5.atr(5) } || 0.0
        atr_med  = safe { cs5.atr(5).median(50) } || atr_now
        atr_now.positive? && atr_med.positive? && (atr_now < atr_med * atr_mult)
      rescue StandardError
        false
      end
      vwap_x    = vwap_crossings(cs5, cross_win) >= 3
      nr5       = narrow_range?(cs5, 5)

      [low_adx, quiet_atr, vwap_x, nr5].count(true) >= 2
    end

    # ---- helpers ----

    def self.vwap_crossings(cs, window)
      vwap = safe { cs.vwap_series(window: window) } # preferred if you have it
      closes = safe { cs.close_series(window: window) }
      if vwap && closes && vwap.size == closes.size && vwap.size > 1
        signs = closes.zip(vwap).map { |c, v| (c <=> v) } # -1, 0, 1
        signs.each_cons(2).count { |a, b| (a <=> b) == -1 || (a <=> b) == 1 }
      else
        # Fallback: approximate with current vwap line if only one value
        0
      end
    rescue StandardError
      0
    end

    def self.narrow_range?(cs, n)
      # NR(n): current bar range <= min range of last n bars
      bars = safe { cs.last_n(n + 1) } || []
      return false unless bars.size >= 2

      rng = ->(b) { (b[:high] - b[:low]).to_f }
      cur = rng.call(bars.last)
      hist = bars[0...-1].map(&rng)
      cur <= hist.min
    rescue StandardError
      false
    end

    def self.safe(&)
      yield
    rescue StandardError
      nil
    end
  end
end