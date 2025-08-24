# frozen_string_literal: true

module Orders
  class Closer < ApplicationService
    def self.call(super_ref:, reason: nil)
      DhanHQ::SuperOrders.close(super_order_id: super_ref) if ENV['PLACE_ORDER'] == 'true'
      snap = State::OrderCache.get(super_ref) || {}
      snap[:status] = 'CLOSED'
      snap[:closed_reason] = reason
      snap[:closed_at] = Time.now.utc.iso8601
      State::OrderCache.put!(super_ref, snap)
      State::Events.log(type: :order_closed, data: snap.slice(:super_ref, :closed_reason, :closed_at))
      snap
    end
  end
end
