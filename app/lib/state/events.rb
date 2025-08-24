# app/lib/state/events.rb
module State
  class Events
    PATH = Rails.root.join("tmp/trader_events.ndjson")

    def self.log(type:, data:)
      File.open(PATH, "a") { |f| f.puts({ ts: Time.now.iso8601, type:, data: }.to_json) }
    rescue => e
      Rails.logger.warn("Event log fail: #{e.class} #{e.message}")
    end

    def self.replay!
      return unless File.exist?(PATH)
      File.foreach(PATH) do |line|
        evt = JSON.parse(line) rescue next
        apply(evt["type"], evt["data"].deep_symbolize_keys)
      end
    end

    def self.apply(type, data)
      case type.to_sym
      when :order_upsert   then State::OrderCache.put!(data[:client_ref], data)
      when :order_delete   then # optional, already handled
      when :position_upsert then State::PositionCache.upsert!(**data.slice(:seg,:sid,:prod), attrs: data)
      when :position_delete then State::PositionCache.delete!(**data.slice(:seg,:sid,:prod))
      end
    end
  end
end
