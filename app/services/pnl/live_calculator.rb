module Pnl
  class LiveCalculator
    def self.for_position(pos)
      # pos is a hash from PositionCache
      ltp = Live::TickCache.ltp(pos[:seg], pos[:sid]).to_f
      avg = (pos[:net_qty].to_i >= 0 ? pos[:buy_avg] : pos[:sell_avg]).to_f
      qty = pos[:net_qty].to_i.abs

      # For options, multiply by lot size (lookup from Instrument/Derivative) if you want total ₹
      lot = pos[:lot_size] || 1
      direction = pos[:net_qty].to_i >= 0 ? +1 : -1
      unreal = (ltp - avg) * qty * lot * direction
      { ltp:, unrealized: unreal.round(2) }
    end
  end
end