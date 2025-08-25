# frozen_string_literal: true

module Orders
  class SuperParamsBuilder
    # Build request body for POST /v2/super/orders
    #
    # Arguments:
    #   instrument:    Instrument/Derivative with #security_id and #exchange_segment
    #   side:          :buy / :sell (or "BUY"/"SELL")
    #   qty:           Integer quantity (lots/shares as per instrument)
    #   entry_type:    :market / :limit
    #   sl_value:      Absolute stop-loss price (premium/price), required
    #   tp_value:      Absolute target price, required
    #   client_ref:    Your idempotency key -> mapped to correlationId
    #
    # Optional:
    #   entry_price:     Limit price (required when entry_type == :limit)
    #   trail_sl_jump:   Trailing jump (absolute price jump)
    #   product_type:    'INTRADAY' | 'CNC' | 'MARGIN' | 'MTF' (default: 'INTRADAY')
    #   validity:        'DAY' (default)
    #   dhan_client_id:  If your gem/config doesn’t inject it, pass here
    #
    # Returns: Hash with Dhan-compliant keys/casing
    def self.call(
      instrument:,
      side:,
      qty:,
      entry_type:,
      sl_value:,
      tp_value:,
      client_ref:,
      entry_price: nil,
      trail_sl_jump: nil,
      product_type: 'INTRADAY',
      validity: 'DAY'
    )
      # ------------ validations ------------
      raise ArgumentError, 'qty must be positive'            if qty.to_i <= 0
      raise ArgumentError, 'sl_value must be present'        if sl_value.nil?
      raise ArgumentError, 'tp_value must be present'        if tp_value.nil?

      ord_type = entry_type.to_s.upcase # "MARKET" | "LIMIT"
      price    = if ord_type == 'LIMIT'
                   PriceMath.round_tick(entry_price).tap do |p|
                     raise ArgumentError, 'limit order requires valid entry_price' if p.nil? || p <= 0
                   end
                 end

      txn_side = side.to_s.upcase # "BUY" | "SELL"

      # ------------ build payload ------------
      {
        # identifiers / routing
        correlation_id: client_ref.to_s, # for tracking/idempotency
        transaction_type: txn_side, # BUY / SELL
        exchange_segment: instrument[:exchange_segment], # e.g. "NSE_FNO"
        product_type: product_type.to_s.upcase, # INTRADAY / CNC / MARGIN / MTF
        order_type: ord_type, # LIMIT / MARKET
        validity: validity.to_s.upcase, # DAY (required by some setups)

        # instrument + qty
        security_id: instrument[:security_id].to_s,
        quantity: qty.to_i,

        # price legs
        price: price, # only for LIMIT (omitted for MARKET)
        target_price: PriceMath.round_tick(tp_value),
        stop_loss_price: PriceMath.round_tick(sl_value),
        trailing_jump: trail_sl_jump && PriceMath.round_tick(trail_sl_jump)
      }.compact
    end
  end
end