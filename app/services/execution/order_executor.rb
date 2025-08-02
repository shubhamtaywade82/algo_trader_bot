module Execution
  class OrderExecutor
    def self.buy_option_ce(instrument)
      # Derive CE option symbol from spot instrument
      derivative = DerivativePicker.pick_ce(instrument)

      order = DhanHQ::Models::Order.new(
        transaction_type: 'BUY',
        exchange_segment: 'NSE_FNO',
        product_type: 'INTRADAY',
        order_type: 'MARKET',
        validity: 'DAY',
        security_id: derivative.security_id,
        quantity: derivative.lot_size
      )

      order.save
    end
  end
end