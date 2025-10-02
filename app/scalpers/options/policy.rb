# frozen_string_literal: true

module Scalpers
  module Options
    class Policy
      def initialize(chain_picker:, logger: Rails.logger)
        @chain_picker = chain_picker
        @logger = logger
      end

      def build_decision(signal:, instrument:, ltp:, config: {})
        leg = @chain_picker.pick(signal:, instrument:, config: config)
        return nil unless leg

        derivative = leg[:derivative]
        price = leg[:ltp].to_f
        return nil unless derivative && price.positive?

        stop_pct = (config[:stop_loss_pct] || 30.0).to_f / 100.0
        target_pct = (config[:target_pct] || 60.0).to_f / 100.0
        min_stop_pct = (config[:min_stop_loss_pct] || 10.0).to_f / 100.0

        risk_per_unit = price * stop_pct
        min_risk = price * min_stop_pct
        risk_per_unit = [risk_per_unit, min_risk].max
        risk_per_unit = [risk_per_unit, price * 0.95].min

        stop_loss = [price - risk_per_unit, price * 0.05].max
        take_profit = price + (price * target_pct)
        stop_loss = stop_loss.round(2)
        take_profit = take_profit.round(2)

        Scalpers::Base::Runner::Decision.new(
          instrument: derivative,
          symbol: derivative.symbol_name || derivative.display_name || leg[:symbol],
          direction: :long,
          action: :enter,
          kind: :option,
          risk_per_unit: risk_per_unit,
          entry_price: price,
          stop_loss: stop_loss,
          take_profit: take_profit,
          metadata: {
            underlying: instrument.symbol_name,
            option_leg: leg,
            reason: signal.reason,
            confidence: signal.confidence,
            regime: signal.regime,
            stop_loss_pct: stop_pct * 100.0,
            target_pct: target_pct * 100.0
          }
        )
      rescue StandardError => e
        @logger.error("[Scalpers::Options::Policy] failed: #{e.message}")
        nil
      end
    end
  end
end
