# frozen_string_literal: true

module Scalpers
  module Options
    class Sizer
      def initialize(base_sizing:, logger: Rails.logger)
        @base = base_sizing
        @logger = logger
      end

      def apply(decision:, cash_balance:, config: {})
        lot_size = decision.instrument.lot_size || config[:lot_size] || 1
        lots = @base.option_lots(
          cash: cash_balance,
          premium: decision.entry_price,
          lot_size: lot_size
        )
        min_lots = config[:min_lots].to_i
        lots = [lots, min_lots].max if min_lots.positive?

        decision.quantity = lots * lot_size
        decision.metadata[:lots] = lots
        decision
      rescue StandardError => e
        @logger.error("[Scalpers::Options::Sizer] failed: #{e.message}")
        nil
      end
    end
  end
end
