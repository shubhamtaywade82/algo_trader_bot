module Execution
  class PositionGuard
    TICK_INTERVAL_MS = 200 # safety if you rate-limit checks

    PositionState = Struct.new(
      :security_id, :segment, :entry_price, :peak_price, :entered_at,
      :trailing_mode, :underlying_symbol, :last_underlying_high_ts, :last_underlying_high
    )

    class << self
      def start(budget)
        @budget = budget
        @states = {}
        @mutex  = Mutex.new
        @running = true
        boot_ws_handlers
      end

      def stop
        @running = false
      end

      def register_intent(intent)
        state = PositionState.new(
          intent.security_id,
          intent.exchange_segment,
          BigDecimal(intent.entry_price.to_s),
          BigDecimal(intent.entry_price.to_s),
          Time.current,
          false,
          intent.underlying_symbol,
          Time.current,
          nil
        )
        @mutex.synchronize { @states[key(intent)] = state }
      end

      private

      def key(intent_or_state)
        "#{intent_or_state.segment}:#{intent_or_state.security_id}"
      end

      def boot_ws_handlers
        # Hook into your WS tick stream
        DhanHQ::WS::Bus.on_tick do |tick|
          next unless @running

          handle_tick(tick)
        end
      end

      def handle_tick(tick)
        k = "#{tick.segment}:#{tick.security_id}"
        state = @states[k]
        return unless state

        ltp = BigDecimal(tick.ltp.to_s)
        return if ltp <= 0

        # Peak tracking
        state.peak_price = [state.peak_price, ltp].max

        # Flip to trailing mode once profit exceeds max(1%, ₹1000)
        profit_pct = (ltp - state.entry_price) / state.entry_price
        if !state.trailing_mode && (profit_pct >= 0.01 || (ltp - state.entry_price) * lot_size_for(state) >= @budget.profit_trigger_rupees)
          state.trailing_mode = true
        end

        # Hard SL: 10% from entry
        if ltp <= state.entry_price * BigDecimal('0.90')
          exit_and_finalize!(state, reason: :hard_sl)
          return
        end

        # Time stop: 3 minutes and not green
        if Time.current - state.entered_at >= 3.minutes && ltp <= state.entry_price
          exit_and_finalize!(state, reason: :time_stop)
          return
        end

        # Trailing exit: 1% drop from peak once trailing_mode
        return unless state.trailing_mode && ltp <= state.peak_price * BigDecimal('0.99')

        exit_and_finalize!(state, reason: :trail_hit)
        nil

        # Optional: consolidation on underlying (update via separate underlying feed)
        # if no new underlying high for 2+ bars, consider exit
        # Pseudocode placeholders:
        # if underlying_consolidating?(state.underlying_symbol)
        #   exit_and_finalize!(state, reason: :underlying_consolidation)
        # end
      end

      def lot_size_for(state)
        # Look up derivative by security_id if needed; fallback 1
        Derivative.find_by(security_id: state.security_id)&.lot_size.to_i.nonzero? || 1
      end

      def exit_and_finalize!(state, reason:)
        # If super order placed → modify/cancel bracket; else market exit
        Orders::Manager.exit_position!(security_id: state.security_id, segment: state.segment, reason: reason)
        # Compute realized_pnl from broker or internal calc
        realized = Orders::Analyzer.realized_pnl_for(state.security_id, state.segment) # returns decimal ₹
        @budget.on_trade_closed!(realized_pnl: realized)
        @mutex.synchronize { @states.delete("#{state.segment}:#{state.security_id}") }
        CloseStrikesManager.unsubscribe_if_unused(state.security_id, state.segment)
      rescue StandardError => e
        Rails.logger.error("[PositionGuard] exit failed #{state.inspect} #{e.class}: #{e.message}")
      end
    end
  end
end