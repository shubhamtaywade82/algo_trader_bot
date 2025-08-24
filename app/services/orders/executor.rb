# frozen_string_literal: true

module Orders
  class Executor < ApplicationService
    # Places a Super Order and records a snapshot in the in-memory cache.
    def self.place_super!(instrument:, qty:, side:, sl:, tp:, trail:, client_ref:, entry_price: nil)
      params = Orders::SuperParamsBuilder.call(
        instrument: instrument,
        side: :buy,
        qty: qty,
        entry_type: :market,
        entry_price: entry_price,
        sl_value: sl,
        tp_value: tp,
        trail_sl_value: trail,
        trail_sl_jump: trail,
        client_ref: client_ref
      )

      resp = if ENV['PLACE_ORDER'] == 'true'
               DhanHQ::SuperOrders.place(params)
             else
               { 'orderId' => "DRY-#{Time.now.to_i}" }
             end
      super_ref = resp['orderId'].to_s

      snapshot = {
        super_ref: super_ref,
        client_ref: client_ref,
        seg: instrument.exchange_segment,
        sid: instrument.security_id.to_s,
        cp: side.to_s.upcase,
        qty: qty,
        entry_price: params[:price] || Live::TickCache.ltp(instrument.exchange_segment, instrument.security_id),
        sl_value: params[:sl_value],
        tp_value: params[:tp_value],
        trail_sl_value: params[:trail_sl_value],
        placed_at: Time.now.utc.iso8601,
        status: 'OPEN'
      }

      State::OrderCache.put!(super_ref, snapshot)
      State::Events.log(type: :order_placed, data: snapshot)
      snapshot
    end
  end
end
