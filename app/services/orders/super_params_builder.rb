# app/services/orders/super_params_builder.rb
module Orders
  class SuperParamsBuilder
    # side: :buy or :sell
    # entry_type: :market or :limit
    def self.call(instrument:, side:, qty:, entry_type:, sl_value:, tp_value:, client_ref:, entry_price: nil, trail_sl_value: nil,
                  trail_sl_jump: nil)
      raise ArgumentError, 'qty must be positive' if qty.to_i <= 0

      price = (entry_type.to_sym == :limit ? PriceMath.round_tick(entry_price) : nil)
      raise ArgumentError, 'limit order requires a valid entry_price' if entry_type.to_sym == :limit && (price.nil? || price <= 0)

      {
        security_id: instrument.security_id,
        exchange_segment: instrument.exchange_segment, # e.g., "NSE_FNO"
        side: side.to_sym, # :buy / :sell
        quantity: qty.to_i,
        order_type: entry_type.to_sym, # :market / :limit
        price: price, # nil for market
        sl_value: PriceMath.round_tick(sl_value),
        tp_value: PriceMath.round_tick(tp_value),
        trail_sl_value: trail_sl_value && PriceMath.round_tick(trail_sl_value),
        trail_sl_jump: trail_sl_jump && PriceMath.round_tick(trail_sl_jump),
        client_ref: client_ref
      }.compact
    end
  end
end
