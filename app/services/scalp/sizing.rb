module Scalp
  class Sizing
    # derivative must respond to lot_size and ltp
    def self.for(derivative, budget:, sl_pct: BigDecimal('0.10'))
      lot_size    = derivative.lot_size.to_i
      entry_price = BigDecimal(derivative.ltp.to_s)
      risk        = budget.risk_rupees

      return OpenStruct.new(qty: 0, sl_pct: sl_pct) if entry_price <= 0 || lot_size <= 0

      lots = (risk / (entry_price * sl_pct * lot_size)).floor
      qty  = [lots, 1].max * lot_size
      OpenStruct.new(qty: qty, sl_pct: sl_pct)
    end
  end
end