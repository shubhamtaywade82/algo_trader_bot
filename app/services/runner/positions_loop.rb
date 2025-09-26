# app/services/runner/positions_loop.rb (inside loop, when you have p, ltp)
Positions::Manager.call(position: Rails.logger.debug)
Exits::MicroTP.call(
  order: p.order,
  ltp: ltp,
  entry_ts: p.created_at,
  side: (if p.order&.side&.to_sym == :buy
           p.option_call? ? :buy_ce : :buy_pe
         else
           :unknown
         end)
)

# app/services/runner/positions_loop.rb
module Runner
  class PositionsLoop
    INTERVAL = 0.5 # seconds
    TZ       = 'Asia/Kolkata'.freeze

    def initialize
      @risk    = Risk::Guard.new
      @running = false
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
        'PositionsLoop'
      rescue StandardError
        nil
      end
      loop do
        break unless @running

        begin
          Position.open.includes(:order, :instrument).find_each do |p|
            manage_position(p)
          end
        rescue StandardError => e
          Rails.logger.error("[PositionsLoop] #{e.class} #{e.message}\n#{e.backtrace&.first(5)&.join("\n")}")
        ensure
          sleep INTERVAL
        end
      end
      Rails.logger.info('[PositionsLoop] stopped')
    end

    def manage_position(p)
      ins = p.instrument
      ltp = Live::TickCache.ltp(ins.exchange_segment, ins.security_id)
      if ltp < (@tp_price * 0.995) && (ltp >= (@entry_price * (1 + @policy.stale_win_min_gain_pct))) &&
         ((now - @last_high_ts) >= @policy.stale_secs)
        exit_market!('STALE_WIN', ltp)
        return
      end

      # update unrealized P&L in rupees for options buying (premium delta * qty)
      entry = p.entry_price.to_f.nonzero? || p.order&.entry_price.to_f
      qty   = p.order&.qty.to_i
      if entry&.positive? && qty.positive?
        p.unrealized_pnl = (ltp.to_f - entry) * qty
        p.save! if p.changed?
      end

      # trailer + micro TP / BE (tighten-only)
      Orders::SuperModifier.call(order: p.order) # no-op if nothing to change
      Exits::MicroTP.call(order: p.order, ltp: ltp, entry_ts: p.created_at, side: infer_side(p))

      # hard-flat if placing another loss would breach cap is not enough;
      # here we protect against live drawdown crossing the cap immediately:
      hard_flat_if_cap_breached!
    end

    def infer_side(_p)
      # For long options we buy premium; if you store CE/PE, wire this properly.
      :buy_ce
    end

    def hard_flat_if_cap_breached!
      cap  = @risk.daily_loss_cap_rupees
      loss = @risk.realized_loss_today_abs
      # approximate unrealized loss across all open positions (only negative P&L counts)
      unreal = Position.open.sum('LEAST(unrealized_pnl, 0)').to_f.abs
      return unless (loss + unreal) >= cap&.positive?

      Rails.logger.warn("[HARD-FLAT] Daily cap breached (#{loss + unreal} >= #{cap}) → closing all + disabling trading")
      flatten_all!
      Setting.put('trading_enabled', 'false')
    end

    def flatten_all!
      Position.open.includes(:order).find_each do |p|
        Orders::Closer.call(order: p.order) if p.order&.super_ref.present?
      rescue StandardError => e
        Rails.logger.error("[HARD-FLAT] close failed pos=#{p.id} #{e.class} #{e.message}")
      end
    end
  end
end
