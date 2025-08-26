# frozen_string_literal: true

module Sizing
  class Capital
    # Defaults can be overridden from ENV/Setting if you like
    DEFAULT_ALLOC_PCT = ENV.fetch('ALLOC_PCT', '0.30').to_f.clamp(0.05, 1.0)
    DEFAULT_BUFFER_PCT = ENV.fetch('PREMIUM_BUFFER_PCT', '0.01').to_f # 1% slippage buffer

    # Returns a Hash with :lots, :qty, :per_lot_cost, :reserved_rupees
    def self.qty_for(leg:, budget:, alloc_pct: DEFAULT_ALLOC_PCT, buffer_pct: DEFAULT_BUFFER_PCT, min_lots: 1, max_lots: nil)
      ltp       = leg[:ltp].to_f
      lot_size  = leg[:lot_size].to_i
      raise ArgumentError, 'invalid leg ltp/lot_size' if ltp <= 0 || lot_size <= 0

      # cost per lot with a small safety buffer for slippage
      per_lot_cost = ((ltp * (1.0 + buffer_pct)) * lot_size).ceil(2)

      # how much money we allow for this trade
      allowance = (budget.available_rupees * alloc_pct).floor(2)

      lots = (allowance / per_lot_cost).floor
      # if 0 but we can afford exactly one lot, try min_lots if affordable
      lots = [min_lots, 1].max if lots <= 0 && allowance >= per_lot_cost

      lots = [lots, max_lots].min if max_lots && lots.positive?

      qty  = lots * lot_size
      {
        lots: lots,
        qty: qty,
        per_lot_cost: per_lot_cost,
        reserved_rupees: lots.positive? ? (per_lot_cost * lots).ceil(2) : 0.0
      }
    end
  end
end
