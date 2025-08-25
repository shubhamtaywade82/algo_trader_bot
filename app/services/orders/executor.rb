# frozen_string_literal: true

module Orders
  class Executor < ApplicationService
    # instrument: Instrument/Derivative
    # side: "BUY"/"SELL"
    # qty: lots/contracts
    # entry_type: :market / :limit
    # risk_params: { sl_value:, tp_value:, trail_sl_value:, trail_sl_jump: }
    # client_ref: unique idempotency key
    def initialize(instrument:, side:, qty:, entry_type:, risk_params:, client_ref:, entry_price: nil)
      @instrument  = instrument
      @side        = side.to_s.upcase
      @qty         = qty.to_i
      @entry_type  = entry_type.to_sym
      @risk_params = risk_params || {}
      @client_ref  = client_ref
      @entry_price = entry_price
    end

    def call
      guard = Risk::Guard.new
      raise 'Trading disabled' unless guard.trading_enabled?

      PgLocks.with_lock("super:#{@instrument.id}") do
        # 1) Idempotency via cache
        if (existing = State::OrderCache.get(@client_ref))
          return existing
        end

        # 2) Build payload
        params = Orders::SuperParamsBuilder.call(
          instrument: @instrument,
          side: @side,
          qty: @qty,
          entry_type: @entry_type,
          entry_price: @entry_price,
          sl_value: @risk_params[:sl_value],
          tp_value: @risk_params[:tp_value],
          trail_sl_jump: @risk_params[:trail_sl_value],
          client_ref: @client_ref
        )

        pp params
        # 3) Place Super Order (returns model with order_id/order_status)
        so = DhanHQ::Models::SuperOrder.create(params)
        raise 'SuperOrder.create failed' unless so&.order_id

        # 4) Cache order snapshot
        order_hash = {
          client_ref: @client_ref,
          broker_order_id: so.order_id,
          status: so.order_status || 'PENDING',
          side: @side,
          qty: @qty,
          entry_type: @entry_type,
          entry_price: params[:price], # avg price may not be immediate
          stop_loss_price: params[:stop_loss_price],
          target_price: params[:target_price],
          trailing_value: params[:trailing_value],
          trailing_jump: params[:trailing_jump],
          exchange_segment: @instrument.exchange_segment,
          security_id: @instrument.security_id,
          pos_key: State::PositionCache.key(seg: @instrument.exchange_segment,
                                            sid: @instrument.security_id,
                                            prod: 'INTRADAY'),
          ts: Time.zone.now
        }.compact
        State::OrderCache.put!(@client_ref, order_hash)

        # 5) Bump PositionCache (optimistic)
        bump_position_cache!(order_hash)

        order_hash
      end
    end

    private

    def bump_position_cache!(o)
      seg = o[:exchange_segment]
      sid = o[:security_id]
      prod = 'INTRADAY'
      cur = State::PositionCache.get(seg:, sid:, prod:) || {}
      net = cur[:net_qty].to_i + (@side == 'BUY' ? @qty : -@qty)

      State::PositionCache.upsert!(
        seg:, sid:, prod:,
        attrs: cur.merge(
          seg: seg, sid: sid, prod: prod,
          net_qty: net,
          buy_avg: cur[:buy_avg], # leave to broker reconcile
          sell_avg: cur[:sell_avg],
          updated_by: 'Orders::Executor'
        )
      )
    end
  end
end