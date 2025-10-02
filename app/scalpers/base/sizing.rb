# frozen_string_literal: true

module Scalpers
  module Base
    # Shared position sizing helpers used by both lanes. The sizing logic keeps
    # the implementation intentionally simple so it can be tuned through config
    # without touching code.
    class Sizing
      DEFAULTS = {
        risk_per_trade_pct: 0.5,
        max_stock_leverage: 2.0,
        default_stop_pct: 1.0,
        option_premium_cap_pct: 1.0,
        min_quantity: 1
      }.freeze

      def initialize(config = {})
        raw_config = config.respond_to?(:to_h) ? config.to_h : {}
        @config = DEFAULTS.merge(raw_config.deep_symbolize_keys)
      end

      def stock_quantity(cash:, price:, atr: nil, lot_size: 1)
        return 0 unless cash.to_f.positive? && price.to_f.positive?

        risk_budget = cash.to_f * (@config[:risk_per_trade_pct].to_f / 100.0)
        stop_distance = atr.to_f.positive? ? atr.to_f : price.to_f * (@config[:default_stop_pct].to_f / 100.0)
        quantity_from_risk = (risk_budget / [stop_distance, 0.01].max).floor

        leverage_cap_qty = ((cash.to_f * @config[:max_stock_leverage].to_f) / price.to_f).floor
        qty = [quantity_from_risk, leverage_cap_qty].reject { |v| v <= 0 }.min || 0
        qty = align_to_lot(qty, lot_size)
        [qty, @config[:min_quantity].to_i].max
      end

      def option_lots(cash:, premium:, lot_size:)
        return 0 unless cash.to_f.positive? && premium.to_f.positive? && lot_size.to_i.positive?

        spend_cap = cash.to_f * (@config[:option_premium_cap_pct].to_f / 100.0)
        lots = (spend_cap / (premium.to_f * lot_size.to_i)).floor
        [lots, 0].max
      end

      private

      def align_to_lot(quantity, lot_size)
        return quantity if lot_size.to_i <= 1

        rem = quantity % lot_size.to_i
        quantity - rem
      end
    end
  end
end
