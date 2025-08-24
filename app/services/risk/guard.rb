module Risk
  class Guard
    DEFAULT_MAX_TICK_AGE = 5 # seconds

    def trading_enabled?
      Setting.fetch_bool('trading_enabled', true)
    end

    def per_trade_risk_rupees
      Setting.fetch_i('risk.per_trade_rupees', 0)
    end

    def daily_loss_cap_rupees
      Setting.fetch_i('risk.daily_loss_cap_rupees', 0)
    end

    def max_trades_per_day
      Setting.fetch_i('risk.max_trades_per_day', 0)
    end

    # ---- Gates ----

    # Returns [allowed(Boolean), reason(String)]
    # expected_risk_rupees: how much you'd risk if this entry is placed (use per_trade_risk_rupees)
    # seg/sid: instrument identifiers for staleness check
    def entry_allowed?(expected_risk_rupees:, seg:, sid:, max_tick_age: DEFAULT_MAX_TICK_AGE)
      return [false, 'trading_disabled'] unless trading_enabled?

      return [false, 'ticks_stale'] if stale?(seg:, sid:, max_age: max_tick_age)

      return [false, 'max_trades_reached'] unless trade_budget_ok?

      return [false, 'daily_loss_cap'] unless daily_loss_ok?(expected_risk_rupees: expected_risk_rupees)

      [true, 'ok']
    end

    # Alias for simpler boolean interface
    # Returns true if entry is allowed, false otherwise
    def ok_to_enter?(expected_risk_rupees:, seg:, sid:, max_tick_age: DEFAULT_MAX_TICK_AGE)
      allowed, _reason = entry_allowed?(expected_risk_rupees: expected_risk_rupees, seg: seg, sid: sid, max_tick_age: max_tick_age)
      allowed
    end

    # Freshness of ticks
    def stale?(seg:, sid:, max_age: DEFAULT_MAX_TICK_AGE)
      tick = begin
        Live::TickCache.get(seg, sid)
      rescue StandardError
        nil
      end
      return true unless tick && tick[:ts].is_a?(Time)

      (Time.zone.now - tick[:ts]) > max_age
    end

    # New entry should not push realized losses beyond the cap
    # Rule: remaining_loss_budget >= expected_risk
    def daily_loss_ok?(expected_risk_rupees:)
      cap  = [daily_loss_cap_rupees, 0].max
      loss = realized_loss_today_abs
      remaining = cap - loss
      remaining >= expected_risk_rupees.to_i
    end

    def trade_budget_ok?
      # Count entries (orders) created today; adjust scope if you count positions instead
      taken = Order.where('created_at::date = ?', Date.current).count
      taken < max_trades_per_day
    end

    # ---- Helpers ----

    # Absolute value of today's realized loss (rupees); profits don't increase budget
    def realized_loss_today_abs
      pnl = Position.where(state: :closed)
                    .where('updated_at::date = ?', Date.current)
                    .sum(:realized_pnl).to_f
      pnl.negative? ? pnl.abs : 0.0
    end
  end
end
