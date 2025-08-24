# lib/tasks/trader.rake
namespace :trader do
  desc 'Start strategy and positions loops'
  task start: :environment do
    instruments = Instrument.where(symbol: %w[NIFTY BANKNIFTY SENSEX]) # adjust
    $strategy_loop  = Runner::StrategyLoop.new(instruments: instruments).start
    $positions_loop = Runner::PositionsLoop.new.start
    puts 'Loops started. Ctrl-C to stop (if foreground).'
    sleep
  end

  desc 'Stop loops (flip kill-switch)'
  task stop: :environment do
    Setting.put('trading_enabled', 'false')
    puts 'Kill-switch flipped off.'
  end
end
