# frozen_string_literal: true

require 'concurrent'

module Live
  class TickCache
    MAP = Concurrent::Map.new

    def self.put(t)
      payload = normalize(t)
      segment = payload[:segment]
      security_id = payload[:security_id]
      return unless segment && security_id

      key = cache_key(segment, security_id)

      MAP.compute(key) do |_, existing|
        # pp payload
        merge_payload(existing, payload)
      end
    end

    def self.get(segment, security_id)
      MAP[cache_key(segment, security_id)]&.dup
    end

    def self.ltp(segment, security_id)
      payload = MAP[cache_key(segment, security_id)]
      return unless payload

      payload[:ltp] || payload[:last_price] || payload[:last_traded_price]
    end

    def self.clear
      MAP.clear
    end

    def self.all
      MAP.each_pair.each_with_object({}) do |(key, value), acc|
        acc[key] = value.dup
      end
    end

    def self.stats
      MAP.each_pair.each_with_object({}) do |(key, value), acc|
        acc[key] = {
          keys: value.keys.sort,
          kind: value[:kind],
          updated_at: value[:received_at]
        }
      end
    end

    def self.normalize(tick)
      return {} unless tick

      hashish = tick.respond_to?(:to_h) ? tick.to_h : tick
      normalized = hashish.each_with_object({}) do |(k, v), acc|
        key = normalize_key(k)
        acc[key] = v
      end

      normalized[:segment] ||= normalized[:exchange_segment]
      normalized[:exchange_segment] ||= normalized[:segment]

      if normalized[:segment]
        normalized[:segment] = normalized[:segment].to_s.upcase
        normalized[:exchange_segment] = normalized[:segment]
      end

      normalized[:security_id] ||= normalized[:securityid]
      normalized[:securityid] ||= normalized[:security_id]
      normalized[:security_id] = normalized[:security_id].to_s if normalized[:security_id]
      normalized[:securityid] = normalized[:securityid].to_s if normalized[:securityid]

      normalized[:kind] = normalize_kind(normalized[:kind]) if normalized.key?(:kind)

      normalized[:ltp] = normalize_price(normalized[:ltp]) if normalized.key?(:ltp)
      normalized[:last_traded_price] = normalize_price(normalized[:last_traded_price]) if normalized.key?(:last_traded_price)
      normalized[:last_price] = normalize_price(normalized[:last_price]) if normalized.key?(:last_price)

      normalized[:ltp] ||= normalized[:last_traded_price] || normalized[:last_price]

      normalized[:open_interest] = normalize_integer(normalized[:open_interest]) if normalized.key?(:open_interest)
      normalized[:oi] = normalize_integer(normalized[:oi]) if normalized.key?(:oi)
      normalized[:oi] ||= normalized[:open_interest]
      normalized[:open_interest] ||= normalized[:oi]

      normalized[:ts] ||= normalized[:last_trade_time] || normalized[:update_time]
      normalized[:ts] = normalize_timestamp(normalized[:ts]) if normalized[:ts]
      normalized[:last_trade_time] = normalize_timestamp(normalized[:last_trade_time]) if normalized[:last_trade_time]
      normalized[:update_time] = normalize_timestamp(normalized[:update_time]) if normalized[:update_time]

      normalized[:received_at] = current_time

      normalized
    end

    def self.cache_key(segment, security_id)
      "#{segment}:#{security_id}"
    end
    private_class_method :cache_key

    def self.merge_payload(existing, incoming)
      return incoming if existing.nil? || existing.empty?

      existing.merge(incoming) do |_key, old_val, new_val|
        new_val.nil? ? old_val : new_val
      end
    end
    private_class_method :merge_payload

    CANONICAL_KEY_MAP = {
      'ExchangeSegment' => :segment,
      'exchangeSegment' => :segment,
      'exchange_segment' => :segment,
      'Segment' => :segment,
      'SecurityId' => :security_id,
      'securityId' => :security_id,
      'LastTradedPrice' => :last_traded_price,
      'LastTradePrice' => :last_traded_price,
      'LastPrice' => :last_price,
      'LastTradeTime' => :last_trade_time,
      'UpdateTime' => :update_time,
      'OpenInterest' => :open_interest,
      'OI' => :open_interest,
      'BestBidPrice' => :best_bid_price,
      'BestAskPrice' => :best_ask_price,
      'BestBidQuantity' => :best_bid_quantity,
      'BestAskQuantity' => :best_ask_quantity
    }.freeze
    private_constant :CANONICAL_KEY_MAP

    def self.normalize_key(key)
      str = key.to_s
      return CANONICAL_KEY_MAP[str] if CANONICAL_KEY_MAP.key?(str)

      snake = str.gsub(/::/, '/').gsub(/([A-Z]+)([A-Z][a-z])/, '\\1_\\2')
                 .gsub(/([a-z\d])([A-Z])/, '\\1_\\2').tr('-', '_').downcase
      snake.to_sym
    end
    private_class_method :normalize_key

    def self.normalize_kind(value)
      return nil if value.nil?
      return value if value.is_a?(Symbol)

      value.to_s.strip.downcase.to_sym
    rescue StandardError
      nil
    end
    private_class_method :normalize_kind

    def self.normalize_price(value)
      return nil if value.nil?
      return value.to_f if value.respond_to?(:to_f)

      value
    end
    private_class_method :normalize_price

    def self.normalize_integer(value)
      return nil if value.nil?
      return value.to_i if value.respond_to?(:to_i)

      Integer(value)
    rescue StandardError
      nil
    end
    private_class_method :normalize_integer

    def self.normalize_timestamp(value)
      return nil if value.nil?
      return value if value.is_a?(Time)

      if value.is_a?(DateTime)
        return value.to_time
      end

      if value.is_a?(Integer) || value.is_a?(Float)
        return Time.zone.at(value.to_f)
      end

      zone = Time.zone || Time
      zone.parse(value.to_s)
    rescue StandardError
      nil
    end
    private_class_method :normalize_timestamp

    def self.current_time
      Time.zone&.now || Time.now
    end
    private_class_method :current_time
  end
end
