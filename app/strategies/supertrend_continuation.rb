# frozen_string_literal: true

class Strategies::SupertrendContinuation < BaseStrategy
  ADX_MIN = 18

  def on_bar(bar:)
    # compute and cache indicators for the latest bar snapshot
    @cs1 = CandleSeries.for(instrument, '1m')
    @cs5 = CandleSeries.for(instrument, '5m')
    @cs15 = CandleSeries.for(instrument, '15m')

    @st5  = @cs5.supertrend(len: 10, factor: 2.0)
    @st15 = @cs15.supertrend(len: 10, factor: 2.0)
    @adx5 = begin
      @cs5.adx(14)
    rescue StandardError
      nil
    end

    @vwap5 = begin
      vwap_for(@cs5)
    rescue StandardError
      nil
    end
    @close = bar[:close] || bar.close

    @long_bias  = st_up?(@st5) && st_up?(@st15) && vwap_ok?(:long)
    @short_bias = st_down?(@st5) && st_down?(@st15) && vwap_ok?(:short)
  end

  # ---------- ENTRY ----------
  def entry_signal
    return nil if recent_signal_cooldown?(seconds: 30) # avoid rapid refires
    return nil unless (@adx5 || 0) >= ADX_MIN

    if @long_bias
      mark_signal!
      return SignalStruct.new(
        type: :entry, side: :buy_ce, reason: 'ST align + ADX + VWAP long',
        confidence: conf_score(:long),
        context: ctx
      )
    end

    if @short_bias
      mark_signal!
      return SignalStruct.new(
        type: :entry, side: :buy_pe, reason: 'ST align + ADX + VWAP short',
        confidence: conf_score(:short),
        context: ctx
      )
    end
    nil
  end

  # ---------- EXIT ----------
  # Basic exits for a runner already in market
  def exit_signal(position_side:, entry_at:, ltp:)
    # opposite ST flip (hard exit)
    if position_side == :buy_ce && st_down?(@st5)
      return SignalStruct.new(type: :exit, side: :close, reason: 'ST flip down', confidence: 1.0, context: ctx)
    elsif position_side == :buy_pe && st_up?(@st5)
      return SignalStruct.new(type: :exit, side: :close, reason: 'ST flip up', confidence: 1.0, context: ctx)
    end

    # VWAP loss + momentum fade (soft exit)
    if position_side == :buy_ce && @vwap5 && @close < @vwap5 && (@adx5 || 0) < ADX_MIN
      return SignalStruct.new(type: :exit, side: :close, reason: 'VWAP loss + weak ADX (CE)', confidence: 0.8, context: ctx)
    elsif position_side == :buy_pe && @vwap5 && @close > @vwap5 && (@adx5 || 0) < ADX_MIN
      return SignalStruct.new(type: :exit, side: :close, reason: 'VWAP loss + weak ADX (PE)', confidence: 0.8, context: ctx)
    end

    # Time stop (e.g., >8m with <0.5R progress) — compute R from settings if you track entry premium
    if entry_at && (Time.now - entry_at) > 8 * 60
      return SignalStruct.new(type: :exit, side: :close, reason: 'time stop 8m', confidence: 0.6, context: ctx)
    end

    nil
  end

  private

  def vwap_for(cs)
    return nil unless cs.respond_to?(:vwap)

    cs.vwap
  end

  def st_up?(st)   = st && (st.respond_to?(:trend_up?)   ? st.trend_up?   : st[:trend] == :up)
  def st_down?(st) = st && (st.respond_to?(:trend_down?) ? st.trend_down? : st[:trend] == :down)

  def vwap_ok?(dir)
    return true unless @vwap5 # if VWAP unavailable, don't block
    return @close > @vwap5 if dir == :long
    return @close < @vwap5 if dir == :short

    true
  end

  def conf_score(dir)
    base = 0.6
    base += 0.2 if dir == :long && st_up?(@st15)
    base += 0.2 if dir == :short && st_down?(@st15)
    base += 0.1 if (@adx5 || 0) >= (ADX_MIN + 5)
    base.clamp(0.0, 1.0)
  end

  def ctx
    {
      adx5: @adx5,
      st5: (if @st5.respond_to?(:trend)
              @st5.trend
            else
              (if @long_bias
                 :up
               else
                 (@short_bias ? :down : :flat)
               end)
            end),
      st15: (@st15.respond_to?(:trend) ? @st15.trend : nil),
      vwap: @vwap5,
      close: @close
    }
  end
end
