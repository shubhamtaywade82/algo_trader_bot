# app/services/sizing.rb
module Sizing
  # qty in contracts (lot-sized)
  def self.qty_for_rupees_risk(premium:, lot_size:, per_trade_rupees:, sl_pct: 0.25)
    return 0 if premium.to_f <= 0 || lot_size.to_i <= 0 || per_trade_rupees.to_i <= 0

    sl_points = PriceMath.round_tick(premium.to_f * sl_pct.to_f)
    per_lot_risk = sl_points * lot_size.to_i
    return 0 if per_lot_risk <= 0

    lots = (per_trade_rupees.to_i / per_lot_risk).floor
    [lots, 1].max * lot_size.to_i
  end
end
