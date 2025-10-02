# frozen_string_literal: true

module Scalpers
  module Options
    class ChainPicker
      def initialize(logger: Rails.logger)
        @logger = logger
      end

      def pick(signal:, instrument:, config: {})
        side = signal.direction == :long ? :ce : :pe
        analyzer = Options::ChainAnalyzer.new(
          underlying: instrument,
          side: side,
          config: config[:analyzer]
        )
        leg = analyzer.call
        return nil unless leg

        return nil if config[:min_oi] && leg[:oi].to_i < config[:min_oi].to_i
        if config[:max_spread_pct].to_f.positive? && leg[:spread_pct].to_f > config[:max_spread_pct].to_f
          return nil
        end

        leg
      rescue StandardError => e
        @logger.error("[Scalpers::Options::ChainPicker] failed: #{e.message}")
        nil
      end
    end
  end
end
