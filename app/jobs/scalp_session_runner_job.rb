class ScalpSessionRunnerJob < ApplicationJob
  queue_as :default

  # Long-running job – ensure delayed_job timeout is high enough or disabled for this queue
  def perform(date: Date.current, capital: 100_000.0, max_day_loss: 3000.0, roster: %w[NIFTY BANKNIFTY], risk_rupees: 600.0)
    session = ScalpSession.find_or_create_by!(trade_date: date) do |s|
      s.capital      = capital
      s.max_day_loss = max_day_loss
      s.params = {
        'risk_rupees' => risk_rupees,
        'roster' => roster,
        'profit_trigger_rupees' => 1000.0,
        'no_entries_after' => '15:00'
      }
    end
    Scalp::Runner.call(session: session)
  end
end