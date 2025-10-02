# frozen_string_literal: true

module Scalpers
  module Stocks
    class Executor
      def initialize(logger: Rails.logger)
        @logger = logger
      end

      def execute(decision:, infra:, config: {})
        qty = decision.quantity.to_i
        return false unless qty.positive?

        side = decision.direction == :long ? 'BUY' : 'SELL'
        client_ref = build_client_ref(decision)
        risk_params = build_risk_params(decision, config)

        infra.with_api_guard do
          Orders::Executor.call(
            instrument: decision.instrument,
            side: side,
            qty: qty,
            entry_type: :market,
            risk_params: risk_params,
            client_ref: client_ref,
            entry_price: decision.entry_price
          )
        end
        true
      rescue StandardError => e
        @logger.error("[Scalpers::Stocks::Executor] failed: #{e.message}")
        false
      end

      private

      def build_client_ref(decision)
        ts = Time.zone.now.strftime('%H%M%S')
        "STOCK-#{decision.symbol}-#{ts}"
      end

      def build_risk_params(decision, config)
        trail = config[:trailing_sl_points]
        trail_jump = config[:trailing_jump]

        {
          sl_value: decision.stop_loss.round(2),
          tp_value: decision.take_profit.round(2),
          trail_sl_value: trail&.to_f,
          trail_sl_jump: trail_jump&.to_f
        }.compact
      end
    end
  end
end
