# app/lib/state/position_cache.rb
module State
  class PositionCache
    KEY = 'positions:v1' # { pos_key => {...} }

    def self.key(seg:, sid:, prod:)
      "#{seg}:#{sid}:#{prod}"
    end

    def self.fetch_all
      Rails.cache.fetch(KEY) { {} }
    end

    def self.get(seg:, sid:, prod:)
      fetch_all[key(seg:, sid:, prod:)]
    end

    def self.upsert!(seg:, sid:, prod:, attrs:)
      h = fetch_all
      k = key(seg:, sid:, prod:)
      h[k] = (h[k] || {}).merge(attrs).merge(updated_at: Time.current)
      Rails.cache.write(KEY, h)
      Events.log(type: :position_upsert, data: h[k].merge(key: k))
      h[k]
    end

    def self.delete!(seg:, sid:, prod:)
      h = fetch_all
      h.delete(key(seg:, sid:, prod:))
      Rails.cache.write(KEY, h)
      Events.log(type: :position_delete, data: { seg:, sid:, prod: })
    end
  end
end
