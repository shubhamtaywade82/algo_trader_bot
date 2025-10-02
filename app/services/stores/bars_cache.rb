# frozen_string_literal: true

require 'singleton'
require 'concurrent'

module Stores
  class BarsCache
    include Singleton

    Entry = Struct.new(:series, :updated_at, keyword_init: true)

    def initialize
      @store = Concurrent::Map.new
    end

    def write(segment:, security_id:, interval:, series:)
      key = build_key(segment, security_id, interval)
      @store[key] = Entry.new(series: series, updated_at: Time.zone.now)
    end

    def series(segment:, security_id:, interval:)
      entry = @store[build_key(segment, security_id, interval)]
      entry&.series
    end

    def stale?(segment:, security_id:, interval:, max_age: 120)
      entry = @store[build_key(segment, security_id, interval)]
      return true unless entry&.updated_at

      Time.zone.now - entry.updated_at > max_age
    end

    private

    def build_key(segment, security_id, interval)
      "#{segment}:#{security_id}:#{interval}"
    end
  end
end
