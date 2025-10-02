# app/services/exits/micro_tp.rb
# Tightens TP and arms BE when live conditions indicate chop after entry.
class Exits::MicroTp < ApplicationService
  # order: Order with super_ref, tp_value, trail_sl_value, entry_price
  # ltp:   current premium
  # entry_ts: Time the position was opened
  # side: :buy_ce or :buy_pe (profit when premium rises for both)
  def initialize(order:, ltp:, entry_ts:, side:)
    @order     = order
    @ltp       = ltp.to_f
    @entry_ts  = entry_ts || Time.now
    @side      = side
    @entry_pr  = order.entry_price.to_f
    @r         = (@entry_pr * 0.25) # 25% SL baseline → 1R
  end

  def call
    return unless valid_order?

    mfe_r   = [(@ltp - @entry_pr) / (@r.nonzero? || 1.0), 0].max
    stalled = stalled_seconds >= 180 # ≥ 3 minutes inside deadband
    spreadp = spread_pct || 0.0

    if chop_live?(mfe_r:, stalled:, spreadp:)
      tighten_tp!
      arm_break_even!
    end

    time_stop!
  rescue StandardError => e
    Rails.logger.warn("[MicroTp] #{e.class} #{e.message}")
  end

  private

  def valid_order?
    @order&.super_ref.present? && @entry_pr.positive?
  end

  def chop_live?(mfe_r:, stalled:, spreadp:)
    # < 0.5R after 5 minutes OR stalled 3m OR spread% > 0.8
    return true if (Time.now - @entry_ts) > 300 && mfe_r < 0.5
    return true if stalled
    return true if spreadp > 0.8

    false
  end

  def tighten_tp!
    # Target: entry + 0.30R from entry premium (or keep current if tighter)
    target = PriceMath.round_tick(@entry_pr + (@r * 0.30))
    cur    = @order.tp_value.to_f
    return if cur.positive? && target >= cur # only tighten (lower TP level)

    Orders::SuperModifier.call(order: @order, new_tp_value: target)
  end

  def arm_break_even!
    # Raise trailing SL to slightly below entry (e.g., entry - 0.10R)
    be = PriceMath.round_tick(@entry_pr - (@r * 0.10))
    cur = @order.trail_sl_value.to_f
    return if cur.positive? && be <= cur # only raise/tighten trail

    Orders::SuperModifier.call(order: @order, new_trail_sl_value: be)
  end

  def time_stop!
    # Hard time stop at 8 minutes with no TP hit
    return unless (Time.now - @entry_ts) > 480

    begin
      DhanHQ::SuperOrders.close(super_order_id: @order.super_ref)
    rescue StandardError
      nil
    end
  end

  # ---- stall & spread helpers ----

  # Tracks last "meaningful move" (> 0.1R) in Rails.cache per order
  def stalled_seconds
    key = "stall:#{@order.super_ref}"
    last = Rails.cache.fetch(key) do
      { ltp: @ltp, ts: Time.now }
    end

    if (@ltp - last[:ltp]).abs >= (@r * 0.10)
      Rails.cache.write(key, { ltp: @ltp, ts: Time.now }, expires_in: 1.hour)
      0
    else
      (Time.now - (last[:ts] || Time.now)).to_i
    end
  end

  def spread_pct
    # Try to read bid/ask via your quote source; fallback to modest value
    quote = safe { Live::Quote.get(@order.instrument.exchange_segment, @order.instrument.security_id) } ||
            safe { DhanHQ::MarketData.quote(@order.instrument.security_id) }
    return 0.4 unless quote

    bid = quote[:bid].to_f
    ask = quote[:ask].to_f
    mid = [(bid + ask) / 2.0, @ltp].compact.max
    return 0.4 if mid <= 0 || ask <= 0 || bid <= 0

    (((ask - bid).abs / mid) * 100.0).round(2)
  rescue StandardError
    0.4
  end

  def safe(&)
    yield
  rescue StandardError
    nil
  end
end
