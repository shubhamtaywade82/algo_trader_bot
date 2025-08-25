# app/services/runner/recent_signals.rb
module Runner
  class RecentSignals
    KEY = 'recent_signals'.freeze

    # store a short-lived fingerprint per underlying (e.g., 30s)
    def self.seen?(underlying_id:, fingerprint:, ttl: 30)
      key = "#{KEY}:#{underlying_id}:#{fingerprint}"
      already = Rails.cache.exist?(key)
      Rails.cache.write(key, true, expires_in: ttl)
      already
    end
  end
end
