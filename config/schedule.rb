# Use this file to easily define all of your cron jobs.
#
# It's helpful, but not entirely necessary to understand cron before proceeding.
# http://en.wikipedia.org/wiki/Cron

# Example:
#
# set :output, "/path/to/my/cron_log.log"
#
# every 2.hours do
#   command "/usr/bin/some_great_command"
#   runner "MyModel.some_method"
#   rake "some:great:rake:task"
# end
#
# every 4.days do
#   runner "AnotherModel.prune_old_records"
# end

# Learn more: http://github.com/javan/whenever
set :output, 'log/cron.log'
env :PATH, ENV.fetch('PATH', nil)

# Start scalping session every weekday at 09:15 IST
every :weekday, at: '9:15 am' do
  runner %(ScalpSessionRunnerJob.perform_later(date: Date.current, capital: 100000.0, max_day_loss: 3000.0, roster: ["NIFTY","BANKNIFTY"], risk_rupees: 600.0))
end

# Safety stop at 15:25 IST
every :weekday, at: '3:25 pm' do
  runner %(ScalpSessionStopJob.perform_later(date: Date.current))
end