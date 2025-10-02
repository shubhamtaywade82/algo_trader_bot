# frozen_string_literal: true

require 'singleton'
require 'concurrent'

module Stores
  class LtpCache
    include Singleton

    def initialize
      @map = Concurrent::Map.new
    end

    def write(segment:, security_id:, ltp:, ts: Time.zone.now)
      key = build_key(segment, security_id)
      @map[key] = {
        ltp: ltp.to_f,
        ts: normalize_ts(ts)
      }
    end

    def fetch(segment:, security_id:)
      @map[build_key(segment, security_id)]
    end

    def ltp(segment:, security_id:)
      fetch(segment:, security_id:)&.dig(:ltp)
    end

    def stale?(segment:, security_id:, max_age: 15)
      data = fetch(segment:, security_id:)
      return true unless data && data[:ts].is_a?(Time)

      Time.zone.now - data[:ts] > max_age
    end

    private

    def build_key(segment, security_id)
      "#{segment}:#{security_id}"
    end

    def normalize_ts(ts)
      return ts if ts.is_a?(Time)
      return Time.zone.at(ts / 1000.0) if ts.is_a?(Integer) || ts.is_a?(Float)

      Time.zone.parse(ts.to_s)
    rescue StandardError
      Time.zone.now
    end
  end
end
