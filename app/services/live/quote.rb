# frozen_string_literal: true

module Live
  class Quote
    # Returns { ltp:, bid:, ask:, ts: } using TickCache first; depth API fallback.
    def self.get(exchange_segment, security_id)
      # 1) WebSocket tick if we have it
      tick = begin
        Live::TickCache.get(exchange_segment, security_id)
      rescue StandardError
        nil
      end
      if tick
        bid = (tick[:best_bid_price] || tick[:bid]).to_f
        ask = (tick[:best_ask_price] || tick[:ask]).to_f
        ltp = (tick[:ltp] || tick[:last_price]).to_f
        return { ltp: ltp, bid: bid, ask: ask, ts: Time.zone.now } if ltp.positive?
      end

      # 2) REST quote fallback
      depth = begin
        DhanHQ::Models::MarketFeed.depth(exchange_segment: exchange_segment, security_id: security_id)
      rescue StandardError
        nil
      end
      if depth
        best_bid = Array(depth[:bids]).first&.dig(:price).to_f
        best_ask = Array(depth[:asks]).first&.dig(:price).to_f
        ltp      = depth[:last_traded_price].to_f.nonzero? || depth[:ltp].to_f
        return { ltp: ltp, bid: best_bid, ask: best_ask, ts: Time.zone.now }
      end

      # 3) as a last resort — plain LTP
      ltp = begin
        Dhanhq::API::Quote.ltp(security_id)
      rescue StandardError
        nil
      end
      return { ltp: ltp.to_f, bid: nil, ask: nil, ts: Time.zone.now } if ltp

      nil
    end
  end
end
