# app/lib/state/order_cache.rb
module State
  class OrderCache
    KEY = 'orders:v1' # single hash stored in Rails.cache

    def self.fetch_all
      Rails.cache.fetch(KEY) { {} } # { client_ref => { ... } }
    end

    def self.get(client_ref) = fetch_all[client_ref]

    def self.put!(client_ref, payload)
      h = fetch_all
      h[client_ref] = payload
      Rails.cache.write(KEY, h)
      Events.log(type: :order_upsert, data: payload)
      true
    end

    def self.find_by_broker_id(oid)
      fetch_all.values.find { |o| o[:broker_order_id] == oid }
    end

    def self.delete!(client_ref)
      h = fetch_all
      h.delete(client_ref)
      Rails.cache.write(KEY, h)
      Events.log(type: :order_delete, data: { client_ref: })
    end
  end
end
