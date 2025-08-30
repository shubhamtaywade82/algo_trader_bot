# frozen_string_literal: true

module Execution
  # Tracks one long options leg. Trails SL upward, honors TP/SL,
  # stale-win harvesting, and can tighten a SuperOrder bracket if used.
  class PositionTracker
    STATUS_ACTIVE = 'ACTIVE'
    STATUS_EXITED = 'EXITED'

    attr_reader :exchange_segment, :security_id, :side, :quantity,
                :entry_price, :highest_ltp, :trail_anchor_price,
                :sl_price, :tp_price, :status, :placed_with_super_order, :product_type

    def initialize(exchange_segment:, security_id:, side:, quantity:, entry_price:, policy:, placed_with_super_order: false, product_type: nil)
      @exchange_segment = exchange_segment.to_s
      @security_id      = security_id.to_s
      @side             = side.to_s # 'BUY'
      @quantity         = quantity.to_i
      @entry_price      = entry_price.to_f
      @policy           = policy
      @placed_with_super_order = !!placed_with_super_order
      @product_type     = product_type&.to_s

      raise ArgumentError, 'only BUY options supported' unless @side == 'BUY'
      raise ArgumentError, 'entry_price must be > 0' if @entry_price <= 0

      @highest_ltp        = @entry_price
      @trail_anchor_price = @entry_price
      @sl_price           = @entry_price * (1 - @policy.sl_pct)
      @tp_price           = @entry_price * (1 + @policy.tp_pct)
      @breakeven_moved    = false
      @last_trail_set_at  = Time.zone.now
      @last_high_ts       = Time.zone.now
      @status             = STATUS_ACTIVE

      maybe_sync_broker_bracket!
    end

    # Called on every tick for this instrument
    def on_ltp(ltp, ts = nil)
      return unless active?

      ltp = ltp.to_f
      now = Time.zone.now

      # Update high water mark
      if ltp > @highest_ltp
        @highest_ltp = ltp
        # @last_high_ts = ts ? Time.zone.at(ts) : now
        @last_high_ts = epoch_to_time(ts)
      end

      # Move SL→entry once breakeven threshold reached
      if !@breakeven_moved && ltp >= (@entry_price * (1 + @policy.breakeven_at_pct))
        @sl_price = @entry_price
        @breakeven_moved = true
        maybe_sync_broker_bracket!
      end

      # Trail on every jump from the last anchor
      if ltp >= @trail_anchor_price * (1 + @policy.trail_jump_pct)
        @trail_anchor_price = ltp
        new_sl = ltp * (1 - @policy.lock_step_pct) # keep some room under the new anchor
        if new_sl > @sl_price
          @sl_price = new_sl
          maybe_sync_broker_bracket!
        end
        @last_trail_set_at = now
      end

      

      # Stale-win: if sufficiently up but no new high for N seconds → book
      if (ltp >= (@entry_price * (1 + @policy.stale_win_min_gain_pct))) && ((now - @last_high_ts) >= @policy.stale_secs)
        exit_market!('STALE_WIN', ltp)
        return
      end

      # Hard exits
      if ltp <= @sl_price
        exit_market!('SL_HIT', ltp)
      elsif ltp >= @tp_price
        exit_market!('TP_HIT', ltp)
      end
    end

    def epoch_to_time(ts)
      if ts && ts > 2_000_000_000
        Time.zone.at(ts / 1000.0)
      else
        (ts ? Time.zone.at(ts) : Time.zone.now)
      end
    end

    def active? = @status == STATUS_ACTIVE

    def snapshot
      {
        segment: @exchange_segment,
        security_id: @security_id,
        side: @side,
        qty: @quantity,
        entry: @entry_price.round(2),
        ltp_high: @highest_ltp.round(2),
        sl: @sl_price.round(2),
        tp: @tp_price.round(2),
        trail_anchor: @trail_anchor_price.round(2),
        breakeven_moved: @breakeven_moved,
        last_trail_set_at: @last_trail_set_at,
        last_high_ts: @last_high_ts,
        status: @status
      }
    end

    private

    def maybe_sync_broker_bracket!
      return unless @placed_with_super_order && (Time.current - (@last_bracket_sync_at || Time.zone.at(0))) >= 2

      # If you used a SuperOrder for entry, tighten the bracket at broker
      DhanHQ::Models::SuperOrder.modify(
        security_id: @security_id,
        exchange_segment: @exchange_segment,
        stop_loss_price: round2(@sl_price),
        target_price: round2(@tp_price)
      )
    rescue StandardError => e
      Rails.logger.warn("[Tracker #{@exchange_segment}:#{@security_id}] bracket modify failed: #{e.class} #{e.message}")
    end

    def exit_market!(reason, ltp)
      return unless active?

      @status = STATUS_EXITED

      # Market SELL to close long CE/PE
      begin
        DhanHQ::Models::Order.create!(
          transaction_type: 'SELL',
          exchange_segment: @exchange_segment,
          product_type:     (@product_type || 'INTRADAY'),
          order_type: 'MARKET',
          validity: 'DAY',
          security_id: @security_id,
          quantity: @quantity
        )
        Rails.logger.info("[Tracker #{@exchange_segment}:#{@security_id}] exit at #{round2(ltp)} (#{reason})")
      rescue StandardError => e
        Rails.logger.error("[Tracker #{@exchange_segment}:#{@security_id}] EXIT order failed: #{e.class} #{e.message}")
      ensure
        begin
          TelegramNotifier.notify_exit("#{@exchange_segment}:#{@security_id}", ltp, reason: reason)
        rescue StandardError
          nil
        end
        Execution::Supervisor.instance.unregister!(exchange_segment: @exchange_segment, security_id: @security_id)
      end
    end

    def round2(n) = (n.to_f * 100).round / 100.0
  end
end
