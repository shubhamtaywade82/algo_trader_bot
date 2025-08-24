module Scalp
  class Runner < ApplicationService
    def initialize(session:)
      @session = session
      @running = true
    end

    def call
      @session.update!(status: :running, equity_peak: @session.equity)
      boot!

      loop do
        break unless @running

        enforce_time_window!
        enforce_kill_switch!
        sleep 1
      end
    ensure
      shutdown!
    end

    def stop!
      @running = false
    end

    private

    def boot!
      @budget = Budget.new(@session)

      Scalp::WSSupervisor.start(mode: :quote)
      CloseStrikesManager.start(Scalp::Roster.list(@session))
      Execution::PositionGuard.start(@budget)

      # 1-minute entries across roster
      Bars::FetchLoop.start(timeframe: '1m', symbols: Scalp::Roster.list(@session)) do |symbol, candles|
        next unless in_entry_window? && @budget.can_trade?

        signal = Rules.entry_signal(symbol, candles)
        next unless signal

        leg   = Strategy::OptionLocator.new(symbol).atm_leg_for(signal.direction) # CE for :bullish, PE for :bearish
        entry = Scalp::Sizing.for(leg, budget: @budget)
        next if entry.qty <= 0

        intent = Execution::DhanRouter.place_super_order!(leg, entry) # super order or fallback path
        Execution::PositionGuard.register_intent(intent)
        @session.increment!(:trades_count)
      end
    end

    def in_entry_window?
      now = Time.current.in_time_zone('Asia/Kolkata')
      cutoff = @budget.no_entries_after
      now < now.change(hour: cutoff.split(':')[0].to_i, min: cutoff.split(':')[1].to_i)
    end

    def enforce_time_window!
      now = Time.current.in_time_zone('Asia/Kolkata')
      return unless now >= now.change(hour: 15, min: 25)

      stop!
    end

    def enforce_kill_switch!
      @session.reload
      @session.update!(equity_peak: [@session.equity_peak, @session.equity].max)
      stop! if @budget.daily_loss_hit?
    end

    def shutdown!
      Execution::PositionGuard.stop
      CloseStrikesManager.stop
      WSSupervisor.stop
      Bars::FetchLoop.stop
      @session.update!(status: :stopped) if @session.running?
    end
  end
end