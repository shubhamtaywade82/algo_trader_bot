# frozen_string_literal: true

module Feed
  # Thin wrapper around Live::WsHub that keeps the LTP cache warm for the
  # scalpers. Designed to be started from the bin entrypoints.
  class Runner
    def initialize(watchlist:, ltp_cache: Stores::LtpCache.instance, logger: Rails.logger)
      @watchlist = Array(watchlist)
      @ltp_cache = ltp_cache
      @logger = logger
      @started = false
    end

    def start!
      return self if @started

      hub = Live::WsHub.instance.start!(mode: :quote)
      hub.on_tick { |tick| handle_tick(tick) }
      hub.subscribe_many(subscription_payload)
      @logger.info("[Feed::Runner] subscribed to #{@watchlist.size} instruments")
      @started = true
      self
    end

    def stop!
      Live::WsHub.instance.stop!
      @started = false
      self
    end

    private

    def subscription_payload
      @watchlist.map do |entry|
        instrument = entry[:instrument]
        { segment: instrument.exchange_segment, security_id: instrument.security_id }
      end
    end

    def handle_tick(tick)
      data = Live::TickCache.normalize(tick)
      segment = data[:segment]
      security_id = data[:security_id]
      ltp = data[:ltp]
      ltp_value = ltp.respond_to?(:to_f) ? ltp.to_f : nil
      return unless segment && security_id && ltp_value && ltp_value.positive?

      @ltp_cache.write(
        segment: segment,
        security_id: security_id,
        ltp: ltp_value,
        ts: data[:ts] || Time.zone.now
      )
    rescue StandardError => e
      @logger.error("[Feed::Runner] failed to handle tick: #{e.message}")
    end
  end
end
