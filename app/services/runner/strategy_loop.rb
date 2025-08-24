# app/services/runner/strategy_loop.rb (inside eval_instrument, before placing order)
cs5  = CandleSeries.for(ins, '5m')
cs15 = CandleSeries.for(ins, '15m')

scalp_mode = Regime::ChopDetector.choppy_pre_entry?(cs5, cs15)

entry_premium = opt[:ltp].to_f
risk_params   = Risk::ScalpParams.for(
  entry_premium: entry_premium,
  mode: scalp_mode ? :scalp : :momentum
)

Orders::Executor.call(
  instrument: Instrument.find_by(security_id: opt[:security_id]),
  side: :buy,
  qty: qty,
  entry_type: :market,
  risk_params: risk_params,
  client_ref: "super:#{ins.id}:#{Time.now.to_i}:#{SecureRandom.hex(3)}"
)

# app/services/runner/strategy_loop.rb
module Runner
  class StrategyLoop
    TICK      = 0.25 # seconds between scans
    TZ        = 'Asia/Kolkata'

    def initialize(instruments:)
      @instruments = Array(instruments)
      @risk        = Risk::Guard.new
      @running     = false
    end

    def start
      return if @running

      @running = true
      @thread = Thread.new { run! }
      @thread
    end

    def stop
      @running = false
      @thread&.join(1)
    end

    private

    def run!
      Thread.current.name = begin
        'StrategyLoop'
      rescue StandardError
        nil
      end
      loop do
        break unless @running

        begin
          break unless @risk.trading_enabled?
          next unless within_trade_window?

          @instruments.each do |ul|
            eval_underlying(ul)
          end
        rescue StandardError => e
          Rails.logger.error("[StrategyLoop] #{e.class} #{e.message}\n#{e.backtrace&.first(5)&.join("\n")}")
        ensure
          sleep TICK
        end
      end
      Rails.logger.info('[StrategyLoop] stopped')
    end

    def within_trade_window?
      Time.use_zone(TZ) do
        now  = Time.zone.now
        wnd1 = now.change(hour: 9,  min: 20)..now.change(hour: 11, min: 15)
        wnd2 = now.change(hour: 13, min: 30)..now.change(hour: 15, min: 5)
        wnd1.cover?(now) || wnd2.cover?(now)
      end
    end

    def eval_underlying(ul)
      # staleness gate (on underlying symbol/index)
      if @risk.stale?(seg: ul.exchange_segment, sid: ul.security_id)
        Rails.logger.debug { "[StrategyLoop] stale ticks for #{ul.symbol}, skipping" }
        return
      end

      # strategy compute on last closed bar (1m)
      cs1  = CandleSeries.for(ul, '1m')
      bar  = cs1.last_bar
      strat = Strategy::Router.for(ul)
      strat.on_bar(bar: bar)

      sig = strat.entry_signal
      return unless sig # no entry

      # trade budget gate + daily-loss gate
      ok, reason = @risk.entry_allowed?(
        expected_risk_rupees: @risk.per_trade_risk_rupees,
        seg: ul.exchange_segment, sid: ul.security_id
      )
      unless ok
        Rails.logger.info("[ENTRY-BLOCKED] #{ul.symbol} reason=#{reason}")
        return
      end

      # ensure at most one order per signal fingerprint (15m ST state + side)
      fp = signal_fingerprint(ul: ul, sig: sig)
      if Runner::RecentSignals.seen?(underlying_id: ul.id, fingerprint: fp, ttl: 30)
        Rails.logger.debug { "[StrategyLoop] duplicate signal suppressed #{ul.symbol} fp=#{fp}" }
        return
      end

      # choose CE/PE strike (ATM±1 with filters)
      cp  = (sig.side == :buy_ce ? :ce : :pe)
      opt = Options::ChainAnalyzer.call(underlying: ul, side: cp)
      unless opt
        Rails.logger.info("[StrategyLoop] no viable option for #{ul.symbol} side=#{cp}")
        return
      end

      # size by rupees risk
      qty = Sizing.qty_for_rupees_risk(
        premium: opt[:ltp].to_f,
        lot_size: opt[:lot_size].to_i,
        sl_pct: 0.25,
        per_trade_rupees: @risk.per_trade_risk_rupees
      )
      if qty <= 0
        Rails.logger.info("[StrategyLoop] qty=0 for #{ul.symbol} (risk too small vs lot)")
        return
      end

      # scalp vs momentum risk params
      cs5  = CandleSeries.for(ul, '5m')
      cs15 = CandleSeries.for(ul, '15m')
      scalp_mode = Regime::ChopDetector.choppy_pre_entry?(cs5, cs15)
      entry_premium = opt[:ltp].to_f
      risk_params = Risk::ScalpParams.for(entry_premium: entry_premium, mode: (scalp_mode ? :scalp : :momentum))

      # final send (market entry by default)
      client_ref = "super:#{ul.id}:#{Time.now.to_i}:#{SecureRandom.hex(3)}"
      Orders::Executor.call(
        instrument: Instrument.find_by(security_id: opt[:security_id]),
        side: :buy,
        qty: qty,
        entry_type: :market, # or :limit with entry_price rounded to 0.05
        risk_params: risk_params,
        client_ref: client_ref
      )

      Rails.logger.info("[ENTRY] #{ul.symbol} #{sig.side} scalp=#{scalp_mode} ltp=#{entry_premium} qty=#{qty} ref=#{client_ref}")
    end

    def signal_fingerprint(ul:, sig:)
      # keep it simple, include side + minute timestamp
      t = Time.now.utc.strftime('%Y%m%d%H%M')
      "#{ul.id}:#{sig.side}:#{t}"
    end
  end
end
