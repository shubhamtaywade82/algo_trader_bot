class AlgoRunner
  def self.execute_all
    Instrument.watchlist.find_each do |inst|
      result = Strategies::BasicTrendStrategy.new(inst).run
      case result
      when :buy_ce
        Execution::OrderExecutor.buy_option_ce(inst)
      end
    end
  end
end