module Orders
  class Manager < ApplicationService
    def self.exit_position!(security_id:, segment:, reason:)
      # Try to close Super Order first (if we have it)
      if (ord = Order.find_by(super_status: %i[submitted modified],
                              instrument_id: Derivative.find_by(security_id: security_id)&.instrument_id))
        Orders::Closer.call(order: ord)
      else
        # Market close fallback – use Dhan plain order
        begin
          DhanHQ::Models::Order.create!(
          transaction_type: 'SELL',
          exchange_segment: segment,
          product_type: 'INTRADAY',
          order_type: 'MARKET',
          validity: 'DAY',
          security_id: security_id,
          quantity: Derivative.find_by(security_id: security_id)&.lot_size || 1
        )
        rescue StandardError
          nil
        end
      end
      Rails.logger.info("[Orders::Manager] exit #{segment}:#{security_id} (#{reason})")
    end
  end
end
