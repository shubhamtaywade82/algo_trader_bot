# frozen_string_literal: true

require 'concurrent'

module Live
  class TickCache
    MAP = Concurrent::Map.new

    def self.put(t)
      MAP["#{t[:segment]}:#{t[:security_id]}"] = t
    end

    def self.get(segment, security_id)
      MAP["#{segment}:#{security_id}"]
    end

    def self.ltp(segment, security_id)
      MAP["#{segment}:#{security_id}"]&.dig(:ltp)
    end

    def self.clear
      MAP.clear
    end
  end
end
