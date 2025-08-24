# app/services/orders/executor.rb
module Orders
  class Executor < ApplicationService
    def initialize(instrument:, side:, qty:, entry_type:, risk_params:, client_ref:, entry_price: nil)
      @instrument = instrument
      @side = side
      @qty = qty
      @entry_type = entry_type
      @risk_params = risk_params
      @client_ref = client_ref
      @entry_price = entry_price
    end

    def call
      guard = Risk::Guard.new
      raise 'Trading disabled' unless guard.trading_enabled?

      PgLocks.with_lock("super:#{@instrument.id}") do
        return Order.find_by(client_ref: @client_ref) if Order.exists?(client_ref: @client_ref)

        params = Orders::SuperParamsBuilder.call(
          instrument: @instrument,
          side: @side,
          qty: @qty,
          entry_type: @entry_type,
          entry_price: @entry_price,
          sl_value: @risk_params[:sl_value],
          tp_value: @risk_params[:tp_value],
          trail_sl_value: @risk_params[:trail_sl_value],
          trail_sl_jump: @risk_params[:trail_sl_jump],
          client_ref: @client_ref
        )

        # Your gem call — adjust to your method signature / return shape
        # Expected resp fields: :super_order_id, :avg_price (if provided by broker immediately)
        resp = DhanHQ::SuperOrders.place(params)

        Order.create!(
          instrument_id: @instrument.id,
          side: @side,
          qty: @qty,
          entry_type: Order.entry_types[@entry_type.to_s],
          client_ref: @client_ref,
          super_ref: resp[:super_order_id],
          super_status: :submitted,
          sl_value: params[:sl_value],
          tp_value: params[:tp_value],
          trail_sl_value: params[:trail_sl_value],
          entry_price: resp[:avg_price]
        )
      end
    end
  end
end
