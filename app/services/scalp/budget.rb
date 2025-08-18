module Scalp
  class Budget
    def initialize(session)
      @session = session
      @allow_entries = true
      @mutex = Mutex.new
    end

    def on_trade_closed!(realized_pnl:)
      @mutex.synchronize do
        @session.increment!(:realized_pnl, realized_pnl)
      end
    end

    def can_trade?
      @allow_entries && !daily_loss_hit?
    end

    def block_new_entries!
      @allow_entries = false
    end

    def daily_loss_hit?
      @session.realized_pnl <= -@session.max_day_loss
    end

    def risk_rupees
      BigDecimal(@session.params['risk_rupees'].to_s.presence || '600.0')
    end

    def profit_trigger_rupees
      BigDecimal(@session.params['profit_trigger_rupees'].to_s.presence || '1000.0')
    end

    def no_entries_after # "15:00" default
      (@session.params['no_entries_after'] || '15:00').to_s
    end

    def roster
      Array(@session.params['roster']).presence || %w[NIFTY BANKNIFTY]
    end
  end
end