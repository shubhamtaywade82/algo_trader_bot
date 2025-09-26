# app/services/risk/to_super_params.rb
module Risk
  class ToSuperParams
    # sl/tp/trail/jump are ABSOLUTE premium values derived from entry premium
    def self.call(entry_premium:, sl_pct: 0.25, tp_pct: 0.50, trail_pct: 0.20, trail_jump_pct: 0.10)
      ep = entry_premium.to_f
      raise ArgumentError, 'entry_premium must be > 0' if ep <= 0

      sl   = [PriceMath.round_tick(ep * sl_pct),   0.05].max
      tp   = [PriceMath.round_tick(ep * tp_pct),   0.05].max
      tval = [PriceMath.round_tick(ep * trail_pct), 0.05].max
      tjmp = [PriceMath.round_tick(ep * trail_jump_pct), 0.05].max

      {
        sl_value: sl,
        tp_value: tp,
        trail_sl_value: tval,
        trail_sl_jump: tjmp
      }
    end
  end
end
