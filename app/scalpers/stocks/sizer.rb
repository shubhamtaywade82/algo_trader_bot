# frozen_string_literal: true

module Scalpers
  module Stocks
    class Sizer
      def initialize(base_sizing:, logger: Rails.logger)
        @base = base_sizing
        @logger = logger
      end

      def apply(decision:, cash_balance:, config: {})
        quantity = @base.stock_quantity(
          cash: cash_balance,
          price: decision.entry_price,
          atr: decision.risk_per_unit,
          lot_size: config[:lot_size] || decision.instrument.lot_size || 1
        )

        decision.quantity = quantity
        decision.metadata[:notional] = quantity * decision.entry_price
        decision
      rescue StandardError => e
        @logger.error("[Scalpers::Stocks::Sizer] failed: #{e.message}")
        nil
      end
    end
  end
end
