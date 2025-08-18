class ScalpSessionStopJob < ApplicationJob
  queue_as :default

  def perform(date: Date.current)
    if (session = ScalpSession.find_by(trade_date: date))
      # simple signal: flip status → runner loop will see it
      session.update!(status: :killed)
    end
  end
end