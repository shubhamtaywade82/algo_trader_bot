# frozen_string_literal: true

module Runner
  class MtfLoop
    class << self
      def start(symbols:, timeframe: '15m')
        stop
        @running = true
        Rails.logger.info("[Mtf] loop start #{symbols.join(', ')} @#{timeframe}")

        Bars::FetchLoop.start(timeframe: timeframe, symbols: symbols) do |symbol, _series|
          break unless @running

          begin
            inst = Instrument.segment_index.find_by(symbol_name: symbol) || Instrument.segment_equity.find_by(display_name: symbol)
            next unless inst

            sig = Strategy::MtfSmcEntry.call(inst)
            next unless sig

            # pick option leg
            leg = Strategy::OptionLocator.new(symbol).atm_leg_for(sig.direction == :bullish ? :bullish : :bearish)

            # sizing (use your existing sizing module)
            budget = Scalp::Budget.current || Scalp::Budget.new(ScalpSession.today!)
            sizing = Scalp::Sizing.for(leg, budget: budget)

            next if sizing.qty <= 0 || !budget.can_trade?

            # # place order
            # intent = Execution::DhanRouter.place_super_order!(leg, sizing)

            # # subscribe ticks for exit/trailing
            # Live::WsHub.instance.subscribe(seg: leg.exchange_segment, sid: leg.security_id)

            # # register with guard
            # Execution::PositionGuard.instance.register(
            #   pos_id: nil, # if you persist immediately, pass id
            #   exchange_segment: leg.exchange_segment,
            #   security_id: leg.security_id,
            #   entry: intent.entry_price,
            #   qty: sizing.qty,
            #   sl_pct: sizing.sl_pct, tp_pct: sizing.tp_pct, trail_pct: sizing.trail_pct,
            #   placed_as: 'super', super_order_id: intent.broker_order_id
            # )

            Rails.logger.info("[Mtf] #{symbol} #{sig.direction.upcase} -> leg=#{leg.security_id} why=#{sig.why}")
          rescue StandardError => e
            Rails.logger.error("[Mtf] fail #{symbol}: #{e.class} #{e.message}")
            Rails.logger.error(
              "[MTF] fail #{symbol}: #{e.class} #{e.message}\n" \
              "#{(e.backtrace || [])[0, 8].join("\n")}"
            )
          end
        end
      end

      def stop
        @running = false
        Bars::FetchLoop.stop
      end
    end
  end
end
