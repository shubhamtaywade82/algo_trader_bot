# frozen_string_literal: true

module Runner
  class AutoPilot < ApplicationService
    WINDOW = { start: '09:20', stop: '15:15' }.freeze

    MODE = Struct.new(:name, :tf, :adx_min, :profit_arm_pct, :time_stop_s, :scalp,
                      keyword_init: true)

    NORMAL = MODE.new(
      name: :normal, tf: '5', adx_min: 20, profit_arm_pct: 0.01, time_stop_s: 480, scalp: false
    )
    SCALP = MODE.new(
      name: :scalp, tf: '3', adx_min: 16, profit_arm_pct: 0.01, time_stop_s: 240, scalp: true
    )

    def initialize(symbols:, mode: :normal, roster: nil)
      @symbols = Array(symbols).presence || %w[NIFTY BANKNIFTY]
      @mode    = (mode.to_s == 'scalp' ? SCALP : NORMAL)
      @roster  = roster || @symbols
      @running = Concurrent::AtomicBoolean.new(false)
      @last_entry_at = {}
    end

    def call
      start!
    end

    def start!
      return if @running.true?

      @running.make_true
      Live::WsHub.instance.start!(mode: :quote)
      subscribe_underlyings!

      # Kick off bars loop (fetch 5m/3m series) and trade loop
      @thread = Thread.new { main_loop }
      self
    end

    def stop!
      @running.make_false
      @thread&.kill
      self
    end

    private

    def main_loop
      loop do
        break unless @running.true?

        now = Time.zone.now
        run_once if inside_session?(now)
        sleep 10 # light cadence; bars fetch is heavier below
      end
    end

    def run_once
      # Pull series for each symbol on the configured TF
      Bars::FetchLoop.start(symbols: @roster, timeframe: tf_for(@mode.tf)) do |sym, series|
        process_symbol(sym, series)
      end
      sleep 12 # let one fetch cycle finish; guard against tight loops
      Bars::FetchLoop.stop
    end

    def process_symbol(sym, series)
      return if Regime::ChopDetector.choppy_pre_entry?(series, series, adx_min: @mode.adx_min)

      trend = holy_or_supertrend(series)
      return if %i[side neutral].include?(trend)

      inst = fetch_instrument(sym)
      return unless inst

      side = (trend == :up ? :ce : :pe)
      leg  = Options::ChainAnalyzer.call(underlying: inst, side: side, config: { strategy_type: (@mode.scalp ? 'intraday' : 'intraday') })
      return unless leg && leg[:ltp].to_f > 0

      # Budget/guard: 30% capital per trade; expect ~1R equal to 10% of premium baseline
      qty = leg[:lot_size].to_i
      return if qty <= 0

      # Skip repeated entries too fast
      return if entered_recently?(sym)

      sl, tp, trail = rr_for(inst, leg, series)
      return unless risk_ok?(inst, expected_risk_rupees: qty * leg[:ltp] * 0.10) # ~10% of premium

      place_super(inst, side, qty, sl: sl, tp: tp, trail: trail)
      @last_entry_at[sym] = Time.current
    rescue StandardError => e
      Rails.logger.warn("[AutoPilot] #{sym} #{e.class}: #{e.message}")
    end

    def rr_for(inst, leg, series)
      # ATR% → map to SL/TP/trail like your AlertProcessors did
      atr = begin
        series.atr(20)
      rescue StandardError
        nil
      end
      atr_pct = if atr && (c = series.closes.last).to_f > 0
                  atr.to_f / c.to_f
                end

      if atr_pct && atr_pct > 0
        sl_pct    = [[atr_pct * 2.0, 0.05].max, 0.18].min
        tp_pct    = [[atr_pct * 4.0, 0.10].max, 0.40].min
        trail_pct = [[atr_pct, 0.03].max, 0.12].min
      else
        sl_pct = 0.10
        tp_pct = 0.20
        trail_pct = 0.03 # defaults
      end

      price = leg[:ltp].to_f
      [
        (price * (1 - sl_pct)),
        (price * (1 + tp_pct)),
        (price * trail_pct)
      ].map { |x| PriceMath.round_tick(x) }
    end

    def place_super(inst, side, qty, sl:, tp:, trail:)
      client_ref = "AP-#{inst.security_id}-#{side}-#{Time.now.to_i}"
      params = Orders::SuperParamsBuilder.call(
        instrument: inst,
        side: :buy,
        qty: qty,
        entry_type: :market,
        sl_value: sl,
        tp_value: tp,
        trail_sl_value: (trail.positive? ? trail : nil),
        trail_sl_jump: (trail.positive? ? trail : nil),
        client_ref: client_ref
      )
      Rails.logger.info("[AutoPilot] Super params → #{params}")
      # Place or dry-run
      if Setting.fetch_bool('PLACE_ORDER', false)
        order = Orders::Executor.call(
          instrument: inst, side: :buy, qty: qty, entry_type: :market,
          risk_params: { sl_value: sl, tp_value: tp, trail_sl_value: trail, trail_sl_jump: trail },
          client_ref: client_ref
        )
        # subscribe the derivative as well
        begin
          Live::WsHub.instance.subscribe(seg: order.instrument.exchange_segment, sid: order.instrument.security_id.to_s)
        rescue StandardError
          nil
        end
        register_for_management(order, inst.symbol_name, side: side)
      else
        notify("💡 DRYRUN SUPER PARAMS\n#{params.inspect}", tag: 'DRYRUN')
      end
    end

    def register_for_management(order, underlying, side:)
      # Attach into PositionGuard
      intent = {
        security_id: order.instrument.security_id,
        exchange_segment: order.instrument.exchange_segment,
        entry_price: order.entry_price || 0.0,
        underlying_symbol: underlying
      }
      Execution::PositionGuard.register_intent(intent)
      # micro‑TP manager can be scheduled via a simple timer on each tick too (optional)
    end

    # ----- helpers -----
    def subscribe_underlyings!
      @symbols.each do |sym|
        inst = fetch_instrument(sym)
        Live::WsHub.instance.subscribe(seg: inst.exchange_segment, sid: inst.security_id.to_s) if inst
      end
    end

    def holy_or_supertrend(series)
      hg = Indicators::HolyGrail.call(candles: to_dhan_hash(series))
      case hg&.bias
      when :bullish then :up
      when :bearish then :down
      else :side
      end
    rescue StandardError
      # fallback: simple supertrend compare
      st = Indicators::Supertrend.new(series: series).call
      return :side if st.empty?

      series.closes.last > st.last ? :up : :down
    end

    def to_dhan_hash(series)
      {
        'timestamp' => series.candles.map { |c| c.timestamp.to_i },
        'open' => series.opens,
        'high' => series.highs,
        'low' => series.lows,
        'close' => series.closes,
        'volume' => series.candles.map(&:volume)
      }
    end

    def fetch_instrument(sym)
      Instrument.segment_index.find_by(symbol_name: sym) || Instrument.segment_equity.find_by(display_name: sym)
    end

    def risk_ok?(inst, expected_risk_rupees:)
      Risk::Guard.new.ok_to_enter?(expected_risk_rupees: expected_risk_rupees.to_i,
                                   seg: inst.exchange_segment, sid: inst.security_id.to_s)
    end

    def entered_recently?(sym)
      t = @last_entry_at[sym]
      t && (Time.current - t) < 90 # cool‑down 90s per underlying
    end

    def inside_session?(now = Time.zone.now)
      t1 = Time.zone.parse(WINDOW[:start])
      t2 = Time.zone.parse(WINDOW[:stop])
      now.between?(t1, t2) && MarketCalendar.trading_day?(now.to_date)
    end

    def tf_for(tf)
      { '1' => '1m', '3' => '3m', '5' => '5m', '15' => '15m' }[tf.to_s] || '5m'
    end
  end
end
