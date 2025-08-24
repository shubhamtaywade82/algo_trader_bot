# frozen_string_literal: true

module Orders
  class Manager < ApplicationService
    def initialize(super_ref:)
      @super_ref = super_ref
    end

    def call
      snap = State::OrderCache.get(@super_ref)
      return unless snap

      seg, sid = snap.values_at(:seg, :sid)
      ltp = Live::TickCache.ltp(seg, sid)
      return unless ltp && ltp.positive?

      pnl_pct = Orders::Analyzer.unrealized_pnl_pct(super_ref: @super_ref)
      spread  = spread_pct(seg, sid, ltp)
      stalled = stalled_seconds(ltp, snap)

      return time_stop!(snap) if time_stop?(snap)

      bump = spread > 0.6 ? 0.0 : 0.10

      if pnl_pct >= 0.25
        be = PriceMath.round_tick(snap[:entry_price])
        Orders::SuperModifier.call(super_ref: @super_ref, new_trail_sl_value: be)
      end

      if stalled >= 90
        new_t = [snap[:trail_sl_value].to_f + PriceMath.round_tick(snap[:entry_price] * bump), snap[:entry_price]].min
        Orders::SuperModifier.call(super_ref: @super_ref, new_trail_sl_value: new_t)
      end

      if thesis_invalid?(snap[:cp])
        Orders::Closer.call(super_ref: @super_ref, reason: 'thesis_flip')
      end
    rescue => e
      Rails.logger.error("[Orders::Manager] #{e.class} #{e.message}")
      nil
    end

    private

    def time_stop?(snap)
      placed = Time.iso8601(snap[:placed_at]) rescue Time.current
      (Time.current - placed) > 8.minutes
    end

    def time_stop!(snap)
      Orders::Closer.call(super_ref: @super_ref, reason: 'time_stop')
    end

    def stalled_seconds(ltp, snap)
      key  = "stall:#{@super_ref}"
      last = Rails.cache.fetch(key) { { ltp: ltp, ts: Time.current } }
      if (ltp - last[:ltp]).abs >= (snap[:entry_price].to_f * 0.10)
        Rails.cache.write(key, { ltp: ltp, ts: Time.current }, expires_in: 1.hour)
        0
      else
        (Time.current - last[:ts]).to_i
      end
    end

    def spread_pct(seg, sid, ltp)
      quote = Live::Quote.get(seg, sid)
      return 0.4 unless quote
      bid, ask = quote.values_at(:bid, :ask).map(&:to_f)
      mid = [(bid + ask) / 2.0, ltp].compact.max
      return 0.4 if mid <= 0 || bid <= 0 || ask <= 0
      (((ask - bid).abs / mid) * 100.0).round(2)
    end

    def thesis_invalid?(cp)
      bias = Setting.fetch_s('autopilot.bias', 'neutral')
      side = cp.to_s.downcase.to_sym
      (bias == 'bullish' && side == :pe) || (bias == 'bearish' && side == :ce)
    end
  end
end
