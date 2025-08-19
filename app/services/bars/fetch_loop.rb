# frozen_string_literal: true

module Bars
  class FetchLoop
    class << self
      def start(symbols:, timeframe: '1m', &on_series)
        stop
        @running = true
        @thread = Thread.new do
          while @running
            begin
              tick = Time.current
              symbols.each do |sym|
                inst = Instrument.segment_index.find_by(symbol_name: sym) || Instrument.segment_equity.find_by(display_name: sym)
                next unless inst

                raw = inst.intraday_ohlc(interval: interval_for(timeframe), days: 20)
                next if raw.blank?

                series = CandleSeries.new(symbol: inst.symbol_name, interval: interval_for(timeframe))
                series.load_from_raw(raw)
                on_series&.call(sym, series)
              end
            rescue StandardError => e
              Rails.logger.error("[Bars::FetchLoop] #{e.class}: #{e.message}")
            ensure
              sleep sleep_to_next_bar(timeframe, from: tick)
            end
          end
        end
      end

      def stop
        @running = false
        @thread&.kill
        @thread = nil
      end

      private

      def interval_for(tf)
        case tf.to_s
        when '1m' then '1'
        when '3m' then '3'
        when '5m' then '5'
        when '15m' then '15'
        else '1'
        end
      end

      def sleep_to_next_bar(tf, from:)
        secs = case tf.to_s
               when '1m'  then 60
               when '3m'  then 180
               when '5m'  then 300
               when '15m' then 900
               else 60
               end
        drift  = (Time.current - from).to_f
        remain = secs - (from.to_i % secs)
        [remain + 2 - drift, 5].max
      end
    end
  end
end
