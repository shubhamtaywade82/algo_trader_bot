# frozen_string_literal: true

module Scalpers
  module Stocks
    class Policy
      def initialize(logger: Rails.logger, allow_shorts: ENV['EQUITY_SHORTS'] == 'true')
        @logger = logger
        @allow_shorts = allow_shorts
      end

      def build_decision(signal:, instrument:, ltp:, config: {})
        direction = signal.direction
        return nil if direction == :short && !shorts_allowed?(config)

        price = ltp.to_f
        return nil unless price.positive?
        return nil if config[:min_price] && price < config[:min_price].to_f
        return nil if config[:max_price] && price > config[:max_price].to_f

        spread_pct = config[:estimated_spread_pct].to_f
        max_spread = config[:max_spread_pct].to_f
        return nil if max_spread.positive? && spread_pct.positive? && spread_pct > max_spread

        atr = signal.metadata[:atr].to_f
        atr_multiple = (config[:atr_multiple] || 1.0).to_f
        sl_pct = (config[:stop_loss_pct] || 1.0).to_f / 100.0
        tp_pct = (config[:target_pct] || 2.0).to_f / 100.0
        rr = (config[:rr_multiple] || 2.0).to_f
        max_sl_pct = (config[:max_stop_loss_pct] || 1.5).to_f / 100.0

        atr_risk = atr.positive? ? atr * atr_multiple : 0.0
        pct_risk = price * sl_pct
        minimum_risk = price * 0.01
        risk_per_unit = [atr_risk, pct_risk, minimum_risk].select { |v| v.positive? }.max
        risk_cap = price * max_sl_pct
        risk_per_unit = [risk_per_unit, risk_cap].min if risk_cap.positive?

        tp_distance_from_rr = risk_per_unit * rr
        tp_distance_from_pct = price * tp_pct
        tp_distance = [tp_distance_from_rr, tp_distance_from_pct].select { |v| v.positive? }.max

        stop_loss = direction == :long ? price - risk_per_unit : price + risk_per_unit
        take_profit = direction == :long ? price + tp_distance : price - tp_distance

        stop_loss = stop_loss.round(2)
        take_profit = [take_profit, 0.01].max.round(2)

        Scalpers::Base::Runner::Decision.new(
          instrument: instrument,
          symbol: instrument.symbol_name,
          direction: direction,
          action: :enter,
          kind: :stock,
          risk_per_unit: risk_per_unit,
          entry_price: price,
          stop_loss: stop_loss,
          take_profit: take_profit,
          metadata: {
            reason: signal.reason,
            confidence: signal.confidence,
            regime: signal.regime,
            spread_pct: spread_pct,
            stop_loss_pct: sl_pct * 100.0,
            target_pct: tp_pct * 100.0,
            config: config
          }
        )
      rescue StandardError => e
        @logger.error("[Scalpers::Stocks::Policy] failed: #{e.message}")
        nil
      end

      private

      def shorts_allowed?(config)
        config.fetch(:allow_shorts, @allow_shorts)
      end
    end
  end
end
