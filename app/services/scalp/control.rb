module Scalp
  class Control
    def self.kill_today!(reason: 'manual')
      session = ScalpSession.find_by(trade_date: Date.current)
      session&.update!(status: :killed, params: session.params.merge(kill_reason: reason))
    end

    def self.stop_today!
      session = ScalpSession.find_by(trade_date: Date.current)
      session&.update!(status: :stopped)
    end
  end
end