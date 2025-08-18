module Scalp
  class Roster
    def self.list(session)
      Array(session.params['roster']).presence || %w[NIFTY BANKNIFTY]
    end
  end
end