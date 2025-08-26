module Execution
  class Budget
    attr_reader :start_cash, :max_day_loss, :profit_trigger_rupees, :allocation_pct

    def initialize(funds_balance:, max_day_loss:, profit_trigger_rupees:, allocation_pct: 0.30)
      # funds_balance should be fetched from DhanHQ::Models::Funds.balance
      balance = funds_balance.to_f

      # cap at 1L if higher, else take balance
      @start_cash = [balance, 100_000].min
      @cash_avail = @start_cash

      @day_pnl = 0.0
      @max_day_loss = max_day_loss.to_f
      @profit_trigger_rupees = profit_trigger_rupees.to_f
      @allocation_pct = allocation_pct.to_f
      @mutex = Mutex.new
    end

    def available_rupees
      @mutex.synchronize { [@cash_avail, 0].max }
    end

    def debit!(rupees)  = @mutex.synchronize { @cash_avail -= rupees.to_f }
    def credit!(rupees) = @mutex.synchronize { @cash_avail += rupees.to_f }
    def add_pnl!(rupees)= @mutex.synchronize { @day_pnl += rupees.to_f }

    def kill_switch?
      @mutex.synchronize { @day_pnl <= -@max_day_loss }
    end
  end
end