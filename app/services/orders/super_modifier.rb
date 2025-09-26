# frozen_string_literal: true

module Orders
  class SuperModifier < ApplicationService
    # Accept either a cached order hash or a client_ref
    def initialize(order: nil, client_ref: nil, new_sl_value: nil, new_tp_value: nil, new_trail_sl_value: nil)
      @order_hash = order || (client_ref && State::OrderCache.get(client_ref))
      @client_ref = client_ref || @order_hash&.dig(:client_ref)
      @new_sl     = new_sl_value && PriceMath.round_tick(new_sl_value)
      @new_tp     = new_tp_value && PriceMath.round_tick(new_tp_value)
      @new_trail  = new_trail_sl_value && PriceMath.round_tick(new_trail_sl_value)
    end

    def call
      return unless @order_hash && @order_hash[:broker_order_id]

      payload = {}

      cur_sl    = @order_hash[:stop_loss_price]&.to_f
      cur_tp    = @order_hash[:target_price]&.to_f
      cur_trail = @order_hash[:trailing_value]&.to_f

      payload[:stop_loss_price] = @new_sl   if @new_sl   && cur_sl   && @new_sl >= cur_sl   # tighten only
      payload[:target_price]    = @new_tp   if @new_tp   && cur_tp   && @new_tp <= cur_tp   # nearer only
      payload[:trailing_value]  = @new_trail if @new_trail && (cur_trail.nil? || @new_trail >= cur_trail)

      return if payload.empty?

      ok = DhanHQ::Models::SuperOrder.new(order_id: @order_hash[:broker_order_id]).modify(payload)

      if ok
        # refresh cache
        merged = @order_hash.merge(
          stop_loss_price: payload[:stop_loss_price] || cur_sl,
          target_price: payload[:target_price] || cur_tp,
          trailing_value: payload[:trailing_value] || cur_trail,
          status: 'MODIFIED',
          ts: Time.zone.now
        )
        State::OrderCache.store!(@client_ref, merged)
      end
      ok
    end
  end
end