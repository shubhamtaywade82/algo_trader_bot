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
    DEMO = MODE.new(
      name: :demo, tf: '1', adx_min: 0, profit_arm_pct: 0.0, time_stop_s: 0, scalp: false
    )

    def initialize(symbols: [], mode: :normal, roster: nil, demo: false)
      @symbols = Array(symbols).presence || %w[NIFTY BANKNIFTY SENSEX]
      @mode    = case mode.to_s
                 when 'scalp' then SCALP
                 when 'demo'  then DEMO
                 else NORMAL
                 end
      @demo = demo || (mode.to_s == 'demo')
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
        sleep(@demo ? 15 : 30) # light cadence; bars fetch is heavier below
      end
    end

    def run_once
      if @demo
        # one-shot fetch per symbol → process immediately
        @roster.each do |sym|
          if (inst = fetch_instrument(sym))
            raw = inst.intraday_ohlc(interval: tf_for(@mode.tf), days: 2)
            if raw.present?
              series = CandleSeries.new(symbol: inst.symbol_name, interval: tf_for(@mode.tf))
              series.load_from_raw(raw)
              process_symbol(sym, series)
            else
              notify_step(:fetch, "no OHLC for #{sym}")
            end
          else
            notify_step(:fetch, "instrument not found for #{sym}")
          end
        end
      else
        # original looping fetch
        Bars::FetchLoop.start(symbols: @roster, timeframe: tf_for(@mode.tf)) do |sym, series|
          process_symbol(sym, series)
        end
        sleep 12
        Bars::FetchLoop.stop
      end
    end

    def process_symbol(sym, series)
      notify_step(:gate_start, "→ #{sym} (#{@mode.name}/tf=#{@mode.tf})")

      if Regime::ChopDetector.choppy_pre_entry?(series, series, adx_min: @mode.adx_min)
        notify_step(:gate_chop, "skip: choppy/adx<#{@mode.adx_min}")
        return
      else
        notify_step(:gate_chop, "ok (adx>=#{@mode.adx_min})")
      end

      trend = holy_or_supertrend(series)
      if %i[side neutral].include?(trend)
        notify_step(:gate_trend, 'skip: neutral/side')
        return
      else
        notify_step(:gate_trend, "ok: #{trend.upcase}")
      end

      inst = fetch_instrument(sym)
      unless inst
        notify_step(:instrument, "skip: not found #{sym}")
        return
      end

      side = (trend == :up ? :ce : :pe)
      notify_step(:picker, "choose side=#{side}")

      leg = Options::ChainAnalyzer.call(
        underlying: inst, side: side,
        config: { strategy_type: (@mode.scalp ? 'intraday' : 'margin') }
      )

      unless leg && leg[:ltp].to_f.positive?
        notify_step(:picker, 'skip: no leg/ltp<=0')
        return
      end
      notify_step(:picker, "picked strike=#{leg[:strike]} ltp=#{leg[:ltp]} lot=#{leg[:lot_size]}")

      qty = leg[:lot_size].to_i
      if qty <= 0
        notify_step(:qty, 'skip: qty<=0')
        return
      end
      notify_step(:qty, "qty=#{qty}")

      if entered_recently?(sym)
        notify_step(:cooldown, 'skip: recent entry cool‑down')
        return
      end
      notify_step(:cooldown, 'ok')

      sl, tp, trail = rr_for(inst, leg, series)
      notify_step(:risk_levels, "SL=#{sl} TP=#{tp} TRL=#{trail}")

      expected_risk = qty * leg[:ltp] * 0.10
      unless risk_ok?(inst, expected_risk_rupees: expected_risk)
        notify_step(:risk_guard, "skip: risk not ok (₹#{expected_risk.round(2)})")
        return
      end
      notify_step(:risk_guard, "ok (₹#{expected_risk.round(2)})")

      place_super(inst, side, qty, sl: sl, tp: tp, trail: trail)
      @last_entry_at[sym] = Time.current unless @demo
      notify_step(:placed, @demo ? "DEMO: would place BUY #{side.upcase}" : 'order placed')
    rescue StandardError => e
      Rails.logger.warn("[AutoPilot] #{sym} #{e.class}: #{e.message}")
      notify_failure(e, :process_symbol)
    end

    def rr_for(inst, leg, series)
      # ATR% → map to SL/TP/trail like your AlertProcessors did
      atr = begin
        series.atr(20)
      rescue StandardError
        nil
      end
      atr_pct = if atr && (c = series.closes.last).to_f.positive?
                  atr.to_f / c
                end

      if atr_pct&.positive?
        sl_pct    = (atr_pct * 2.0).clamp(0.05, 0.18)
        tp_pct    = (atr_pct * 4.0).clamp(0.10, 0.40)
        trail_pct = atr_pct.clamp(0.03, 0.12)
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
      notify_step(:super_params, params.inspect)

      # DEMO forces dry-run; otherwise keep existing PLACE_ORDER flag
      if @demo || !Setting.fetch_bool('PLACE_ORDER', false)
        notify("💡 DRYRUN SUPER PARAMS\n#{params.inspect}", tag: 'DRYRUN')
      else
        order = Orders::Executor.call(
          instrument: inst, side: :buy, qty: qty, entry_type: :market,
          risk_params: { sl_value: sl, tp_value: tp, trail_sl_value: trail, trail_sl_jump: trail },
          client_ref: client_ref
        )
        begin
          Live::WsHub.instance.subscribe(seg: order.instrument.exchange_segment, sid: order.instrument.security_id.to_s)
        rescue StandardError
          nil
        end
        register_for_management(order, inst.symbol_name, side: side)
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

    def demo_mode?
      @demo
    end

    def holy_or_supertrend(series)
      cfg = demo_mode? ? Indicators::HolyGrail.demo_config : {}
      hg = Indicators::HolyGrail.call(candles: to_dhan_hash(series), config: cfg)

      notify_step(:demo_gate, "HolyGrail cfg=#{cfg.inspect}") if demo_mode?
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
      return false if @demo

      t = @last_entry_at[sym]
      t && (Time.current - t) < 90 # cool‑down 90s per underlying
    end

    def inside_session?(now = Time.zone.now)
      return true if @demo

      t1 = Time.zone.parse(WINDOW[:start])
      t2 = Time.zone.parse(WINDOW[:stop])
      now.between?(t1, t2) && MarketCalendar.trading_day?(now.to_date)
    end

    def tf_for(tf)
      { '1' => '1', '3' => '3', '5' => '5', '15' => '15' }[tf.to_s] || '5'
    end

    def notify_step(action, message)
      Rails.logger.info("[AutoPilot] #{action} → #{message}")
    end

    def numeric_value?(value)
      value.is_a?(Numeric) || value.to_s.match?(/\A-?\d+(\.\d+)?\z/)
    end
  end
end
