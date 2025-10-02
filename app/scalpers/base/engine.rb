# frozen_string_literal: true

module Scalpers
  module Base
    # Computes directional signals by blending Supertrend, simple BOS/SMC structure
    # checks, relative volume and a light-weight ATR regime classifier. The intent is
    # to provide a single "structure" signal that both the stock and options scalpers
    # can consume. Each call returns a Signal struct with enough metadata for downstream
    # policies to make lane-specific decisions.
    class Engine
      Signal = Struct.new(
        :symbol,
        :direction,
        :confidence,
        :regime,
        :reason,
        :metadata,
        keyword_init: true
      )

      DEFAULT_CONFIG = {
        supertrend_period: 10,
        supertrend_multiplier: 3.0,
        volume_lookback: 20,
        volume_factor: 1.2,
        atr_period: 14,
        regime_thresholds: {
          compressed: 0.6,
          expanded: 1.4
        }
      }.freeze

      def initialize(config = {})
        @config = DEFAULT_CONFIG.deep_merge(config || {})
        @logger = @config[:logger] || Rails.logger
      end

      # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
      def signal_for(symbol:, series_1m:, series_5m:)
        return nil unless series_1m&.candles&.any? && series_5m&.candles&.any?

        trend_1m = supertrend_direction(series_1m)
        trend_5m = supertrend_direction(series_5m)
        return nil unless trend_1m && trend_5m
        return nil unless trend_1m == trend_5m

        direction = trend_1m == :bullish ? :long : :short
        structure_ok, structure_reason = structure_confirmation(direction:, series: series_5m)
        return nil unless structure_ok

        volume_ok = volume_confirmation?(series: series_1m, direction: direction)
        return nil unless volume_ok

        regime = atr_regime(series: series_1m)
        confidence = base_confidence(direction:, regime: regime)

        Signal.new(
          symbol: symbol,
          direction: direction,
          confidence: confidence,
          regime: regime,
          reason: structure_reason,
          metadata: {
            supertrend: trend_1m,
            volume_spike: volume_ok,
            regime: regime,
            atr: latest_atr(series: series_1m),
            last_close: series_1m.candles.last&.close
          }
        )
      rescue StandardError => e
        @logger.error("[Scalpers::Base::Engine] signal_for failed for #{symbol}: #{e.class} #{e.message}")
        nil
      end
      # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

      private

      def supertrend_direction(series)
        indicator = Indicators::Supertrend.new(series:, period: @config[:supertrend_period], multiplier: @config[:supertrend_multiplier])
        values = indicator.call
        idx = last_numeric_index(values)
        return nil unless idx

        candle = series.candles[idx]
        return nil unless candle

        candle.close >= values[idx] ? :bullish : :bearish
      rescue StandardError => e
        @logger.error("[Scalpers::Base::Engine] supertrend_direction failed: #{e.message}")
        nil
      end

      def last_numeric_index(values)
        return nil unless values.respond_to?(:each_with_index)

        values.each_with_index.reverse_each do |v, i|
          return i if v.is_a?(Numeric)
        end
        nil
      end

      def structure_confirmation(direction:, series:)
        candle = series.candles.last
        return [false, 'insufficient_data'] unless candle

        if direction == :long
          if candle.close > (series.previous_swing_high || candle.close - 0.01)
            [true, 'bos_up']
          elsif series.liquidity_grab_up?
            [true, 'liquidity_grab_up']
          else
            [false, 'structure_not_confirmed']
          end
        else
          if candle.close < (series.previous_swing_low || candle.close + 0.01)
            [true, 'bos_down']
          elsif series.liquidity_grab_down?
            [true, 'liquidity_grab_down']
          else
            [false, 'structure_not_confirmed']
          end
        end
      end

      def volume_confirmation?(series:, direction:)
        lookback = @config[:volume_lookback]
        factor = @config[:volume_factor]
        candles = series.candles.last(lookback)
        return false if candles.size < lookback

        avg_volume = candles[0...-1].sum(&:volume) / [candles.size - 1, 1].max.to_f
        last_volume = candles.last.volume.to_f
        return false unless last_volume.positive?

        bias = direction == :long ? 1.0 : 0.95 # allow slightly lower volume for shorts
        last_volume >= avg_volume * factor * bias
      rescue StandardError => e
        @logger.error("[Scalpers::Base::Engine] volume_confirmation failed: #{e.message}")
        false
      end

      def atr_regime(series:)
        atr_value = latest_atr(series:)
        return :unknown unless atr_value&.positive?

        recent_closes = series.candles.last(20).map(&:close)
        return :unknown if recent_closes.size < 2

        avg_price = recent_closes.sum / recent_closes.size.to_f
        normalized_atr = atr_value / avg_price

        thresholds = @config[:regime_thresholds]
        return :compressed if normalized_atr <= thresholds[:compressed]
        return :expanded if normalized_atr >= thresholds[:expanded]

        :normal
      rescue StandardError => e
        @logger.error("[Scalpers::Base::Engine] atr_regime failed: #{e.message}")
        :unknown
      end

      def latest_atr(series:)
        atr = series.atr(@config[:atr_period])
        return atr if atr.is_a?(Numeric)

        Array(atr).compact.last
      rescue StandardError
        nil
      end

      def base_confidence(direction:, regime:)
        base = direction == :long ? 0.55 : 0.5
        case regime
        when :expanded then base + 0.15
        when :normal   then base
        when :compressed then base - 0.1
        else
          base - 0.05
        end
      end
    end
  end
end
