# frozen_string_literal: true

module Orders
  class SuperModifier < ApplicationService
    # Tighten trailing/targets for a super order snapshot stored in cache.
    def self.call(super_ref:, new_sl_value: nil, new_tp_value: nil, new_trail_sl_value: nil)
      snap = State::OrderCache.get(super_ref)
      return unless snap

      new_sl    = new_sl_value && PriceMath.round_tick(new_sl_value)
      new_tp    = new_tp_value && PriceMath.round_tick(new_tp_value)
      new_trail = new_trail_sl_value && PriceMath.round_tick(new_trail_sl_value)

      payload = {}
      payload[:sl_value]       = new_sl    if new_sl && snap[:sl_value] && new_sl >= snap[:sl_value]
      payload[:tp_value]       = new_tp    if new_tp && snap[:tp_value] && new_tp <= snap[:tp_value]
      payload[:trail_sl_value] = new_trail if new_trail && (snap[:trail_sl_value].nil? || new_trail >= snap[:trail_sl_value])
      return if payload.empty?

      DhanHQ::SuperOrders.modify(super_order_id: super_ref, **payload) if ENV['PLACE_ORDER'] == 'true'

      snap.merge!(payload)
      State::OrderCache.put!(super_ref, snap)
      State::Events.log(type: :order_modified, data: snap.slice(:super_ref, :sl_value, :tp_value, :trail_sl_value))
      snap
    end
  end
end
