# frozen_string_literal: true

class Strategy::Router
  def self.for(instrument)
    # Feature flag or config lookup could live here
    Strategies::SupertrendContinuation.new(instrument: instrument, tf: '5m')
  end
end
