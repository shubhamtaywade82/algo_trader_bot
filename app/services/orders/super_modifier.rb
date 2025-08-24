# app/services/orders/super_modifier.rb
module Orders
  class SuperModifier < ApplicationService
    # Any of the new_* values may be nil; only send the ones you want to change.
    def initialize(order:, new_sl_value: nil, new_tp_value: nil, new_trail_sl_value: nil)
      @order = order
      @new_sl = new_sl_value && PriceMath.round_tick(new_sl_value)
      @new_tp = new_tp_value && PriceMath.round_tick(new_tp_value)
      @new_trail = new_trail_sl_value && PriceMath.round_tick(new_trail_sl_value)
    end

    def call
      return if @order&.super_ref.blank?

      payload = {}

      # Tighten-only policy (for long calls/puts):
      # - SL is distance/level semantics vary across brokers; safest: only increase SL price if your convention = absolute price.
      #   If you store SL as absolute premium level: tightening means moving SL *upwards* (closer to current) for long positions.
      payload[:sl_value] = @new_sl if @new_sl && @order.sl_value && @new_sl >= @order.sl_value

      # - TP can only be decreased (closer target), never widened outward.
      payload[:tp_value] = @new_tp if @new_tp && @order.tp_value && @new_tp <= @order.tp_value

      # - Trailing SL value can only be raised (tighter).
      payload[:trail_sl_value] = @new_trail if @new_trail && (@order.trail_sl_value.nil? || @new_trail >= @order.trail_sl_value)

      return if payload.empty?

      resp = DhanHQ::SuperOrders.modify(
        super_order_id: @order.super_ref,
        **payload
      )

      # Update only on accept
      @order.update!(
        sl_value: payload[:sl_value] || @order.sl_value,
        tp_value: payload[:tp_value] || @order.tp_value,
        trail_sl_value: payload[:trail_sl_value] || @order.trail_sl_value,
        super_status: :modified
      )
      resp
    end
  end
end
