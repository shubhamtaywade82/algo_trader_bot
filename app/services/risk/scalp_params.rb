# app/services/risk/scalp_params.rb
# Convenience wrapper for building scalp or momentum params.
module Risk
  class ScalpParams
    def self.for(entry_premium:, mode:)
      case mode
      when :scalp
        Risk::ToSuperParams.call(
          entry_premium: entry_premium,
          sl_pct: 0.25,  # keep risk constant
          tp_pct: 0.30,  # smaller, grab-able TP
          trail_pct: 0.18,
          trail_jump_pct: 0.10
        )
      else # :momentum (default)
        Risk::ToSuperParams.call(
          entry_premium: entry_premium,
          sl_pct: 0.25,
          tp_pct: 0.50,
          trail_pct: 0.20,
          trail_jump_pct: 0.10
        )
      end
    end
  end
end
