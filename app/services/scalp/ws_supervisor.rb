# frozen_string_literal: true

module Scalp
  class WSSupervisor
    def initialize(indices:, mode: :quote)
      @mode = mode
      @indices = indices
      @bus = TickBus.new
      @agg = CandleAggregator.new(interval_sec: 300) { |ev| on_candle_close(ev) }
      @running = Concurrent::AtomicBoolean.new(false)
    end
    attr_reader :agg

    def start!
      return if @running.true?

      @running.make_true

      # seed 5m series for indices (from your Instrument helpers)
      @indices.each do |it|
        inst = Instrument.find_by(security_id: it[:security_id].to_s)
        next unless inst

        cs = inst.candle_series(interval: '5') || CandleSeries.new(symbol: inst.symbol, interval: '5')
        @agg.seed_series!(segment: it[:segment], security_id: it[:security_id], series: cs)
      end

      @ws = DhanHQ::WS::Client.new(mode: @mode).start
      @ws.on(:tick) { |t| on_tick(t) }
      @indices.each { |i| @ws.subscribe_one(segment: i[:segment], security_id: i[:security_id]) }

      @drainer = Thread.new do
        loop do
          @bus.drain
          sleep 0.01 if @running.true?
        end
      end
      self
    end

    def stop!
      @running.make_false
      @ws&.stop
      @drainer&.kill
    end

    def subscribe_option(seg:, sid:) = @ws.subscribe_one(segment: seg, security_id: sid)

    private

    def on_tick(t)
      TickCache.put(t)
      @bus.publish("ticks.#{t[:segment]}.#{t[:security_id]}", t)
      @agg.on_tick(t)
      CloseStrikesManager.instance.on_index_tick(t) # dynamic close strikes
    end

    def on_candle_close(ev)
      Strategy::SupertrendOptionLong.instance.on_index_candle(ev[:segment], ev[:security_id])
    end
  end
end