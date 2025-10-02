# frozen_string_literal: true

module Scalpers
  module Options
    class Executor
      def initialize(logger: Rails.logger)
        @logger = logger
      end

      def execute(decision:, infra:, config: {})
        qty = decision.quantity.to_i
        return false unless qty.positive?

        client_ref = build_client_ref(decision)
        risk_params = build_risk_params(decision, config)

        infra.with_api_guard do
          Orders::Executor.call(
            instrument: decision.instrument,
            side: 'BUY',
            qty: qty,
            entry_type: :market,
            risk_params: risk_params,
            client_ref: client_ref,
            entry_price: decision.entry_price
          )
        end
        true
      rescue StandardError => e
        @logger.error("[Scalpers::Options::Executor] failed: #{e.message}")
        false
      end

      private

      def build_client_ref(decision)
        ts = Time.zone.now.strftime('%H%M%S')
        "OPT-#{decision.symbol}-#{ts}"
      end

      def build_risk_params(decision, config)
        {
          sl_value: decision.stop_loss.round(2),
          tp_value: decision.take_profit.round(2),
          trail_sl_value: config[:trailing_sl_points]&.to_f,
          trail_sl_jump: config[:trailing_jump]&.to_f
        }.compact
      end
    end

    class Executor
      class Demo < Executor
        def execute(decision:, infra:, config: {})
          @logger.info(
            "[Scalpers::Options::Demo] BUY #{decision.symbol} qty=#{decision.quantity} "\
            "entry=#{decision.entry_price} stop=#{decision.stop_loss} target=#{decision.take_profit}"
          )
          true
        end
      end
    end
  end
end
