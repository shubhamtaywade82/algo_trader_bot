module Risk
  class Guard
    DEFAULT_MAX_TICK_AGE = 30 # seconds

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

      pp stale?(seg:, sid:, max_age: max_tick_age)
      # return [false, 'ticks_stale'] if stale?(seg:, sid:, max_age: max_tick_age)

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
      max = max_trades_per_day.to_i
      return true if max <= 0 # 0 or negative => unlimited

      open_positions = State::PositionCache.fetch_all.values.count do |pos|
        pos[:net_qty].to_i.nonzero?
      end

      open_positions < max
    end

    # ---- Helpers ----

    # Absolute value of today's realized loss (rupees); profits don't increase budget
    # Absolute value of today's realized loss (rupees); profits don't increase budget
    # Reads from State::PositionCache snapshots. We expect PositionCache upserts to set
    # :realized (cumulative realized PnL for that leg) and a timestamp (:updated_at or :ts).
    def realized_loss_today_abs
      today = Date.current
      positions = State::PositionCache.fetch_all.values

      realized_loss = positions.sum do |p|
        # pick a timestamp from the cache snapshot
        ts = p[:updated_at] || p[:ts]
        t  = if ts.is_a?(Time)
               ts
             else
               begin
                 Time.zone.parse(ts.to_s)
               rescue StandardError
                 nil
               end
             end
        next 0.0 unless t && t.to_date == today

        r = p[:realized].to_f
        r.negative? ? r : 0.0
      end

      realized_loss.abs
    end
  end
end
