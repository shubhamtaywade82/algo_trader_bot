# app/services/orders/manager.rb
# frozen_string_literal: true

module Orders
  class Manager < ApplicationService
    # Try to flatten using SuperOrder; fallback to plain MARKET opposite leg
    def self.exit_position!(security_id:, segment:, reason:)
      # 1) If we have a cached super order for this instrument, cancel it.
      order = State::OrderCache.fetch_all.values.find do |o|
        o[:security_id].to_i == security_id.to_i && o[:exchange_segment].to_s == segment.to_s
      end

      if order&.dig(:broker_order_id)
        begin
          ok = DhanHQ::Models::SuperOrder.new(order_id: order[:broker_order_id]).cancel('ENTRY_LEG')
          Rails.logger.info("[Orders::Manager] cancel super #{segment}:#{security_id} => #{ok} (#{reason})")
          return true if ok
        rescue StandardError => e
          Rails.logger.warn("[Orders::Manager] super cancel failed: #{e.class} #{e.message}")
        end
      end

      # 2) Fallback: plain opposite market order
      begin
        side = (infer_side_from_pos(segment:, security_id:) == 'LONG' ? 'SELL' : 'BUY')
        lot  = Derivative.find_by(security_id: security_id)&.lot_size || 1

        DhanHQ::Models::Order.create!(
          transaction_type: side,
          exchange_segment: segment,
          product_type: 'INTRADAY',
          order_type: 'MARKET',
          validity: 'DAY',
          security_id: security_id,
          quantity: lot
        )
        Rails.logger.info("[Orders::Manager] market flatten #{segment}:#{security_id} (#{reason})")
        true
      rescue StandardError => e
        Rails.logger.error("[Orders::Manager] fallback exit failed #{segment}:#{security_id} – #{e.class}: #{e.message}")
        false
      end
    end

    def self.infer_side_from_pos(segment:, security_id:)
      pos = State::PositionCache.get(seg: segment, sid: security_id, prod: 'INTRADAY') || {}
      qty = pos[:net_qty].to_i
      qty >= 0 ? 'LONG' : 'SHORT'
    end
  end
end