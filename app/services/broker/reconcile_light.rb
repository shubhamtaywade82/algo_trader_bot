# app/services/broker/reconcile_light.rb
module Broker
  class ReconcileLight < ApplicationService
    def call
      reconcile_positions
      reconcile_orders # optional; super orders list is useful
    end

    def reconcile_positions
      broker = DhanHQ::Models::Position.all # GET /v2/positions
      seen = {}
      broker.each do |p|
        seg = p.exchange_segment; sid = p.security_id; prod = p.product_type
        k = State::PositionCache.key(seg:, sid:, prod:)
        seen[k] = true

        State::PositionCache.upsert!(
          seg:, sid:, prod:,
          attrs: {
            trading_symbol: p.trading_symbol,
            net_qty:        p.net_qty.to_i,
            buy_avg:        p.buy_avg.to_f,
            sell_avg:       p.sell_avg.to_f,
            realized:       p.realized_profit.to_f,
            unrealized:     p.unrealized_profit.to_f,
            external:       external?(k) # mark external if not in local orders
          }
        )
      end

      # remove closed entries
      State::PositionCache.fetch_all.keys.each do |k|
        State::PositionCache.delete!(**split(k)) unless seen[k]
      end
    end

    def reconcile_orders
      # optional: only when you need status or leg details
      supers = DhanHQ::Models::SuperOrder.all # GET /v2/super/orders
      supers.each do |o|
        cref = o["correlationId"]
        next unless cref
        State::OrderCache.put!(cref, {
          client_ref: cref,
          broker_order_id: o["orderId"],
          status: o["orderStatus"],
          quantity: o["quantity"].to_i,
          filled_qty: o["filledQty"].to_i,
          remaining_quantity: o["remainingQuantity"].to_i,
          target_price: o.dig("legDetails")&.find{_1["legName"]=="TARGET_LEG"}&.[]("price"),
          stop_loss_price: o.dig("legDetails")&.find{_1["legName"]=="STOP_LOSS_LEG"}&.[]("price"),
          trailing_jump: o.dig("legDetails")&.find{_1["legName"]=="STOP_LOSS_LEG"}&.[]("trailingJump")
        }.compact)
      end
    end

    def split(k)
      seg, sid, prod = k.split(":")
      { seg:, sid: sid.to_i, prod: }
    end

    def external?(k)
      # If no local order references this pos key recently, consider it external
      State::OrderCache.fetch_all.values.none? { |o| o[:pos_key] == k }
    end
  end
end
