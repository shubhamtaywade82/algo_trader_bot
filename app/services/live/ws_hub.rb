# frozen_string_literal: true

require 'singleton'
require 'concurrent'

module Live
  class WsHub
    include Singleton

    attr_reader :exit_hook_attached

    def initialize
      @running  = Concurrent::AtomicBoolean.new(false)
      @client   = nil
      @subs     = Concurrent::Set.new # "SEG:SID"
      @handlers = Concurrent::Array.new
    end

    def start!(mode: :quote)
      return self if @running.true?

      @client = DhanHQ::WS::Client.new(mode: mode).start
      @client.on(:tick) { |t| handle_tick(t) }
      @running.make_true
      self
    end

    def stop!
      return self unless @running.true?

      @running.make_false
      @client&.disconnect! # graceful + no reconnect
      @client = nil
      self
    end

    # Subscribe single instrument (idempotent)
    def subscribe(seg:, sid:)
      key = k(seg, sid)
      return self if @subs.include?(key)

      @subs.add(key)
      @client&.subscribe_one(segment: seg, security_id: sid)
      self
    end

    # Unsubscribe (if you want to shrink the stream)
    def unsubscribe(seg:, sid:)
      key = k(seg, sid)
      return self unless @subs.include?(key)

      @subs.delete(key)
      @client&.unsubscribe_one(segment: seg, security_id: sid)
      self
    end

    # Convenient multi-subscribe
    def subscribe_many(list)
      Array(list).each do |entry|
        payload = normalize_subscription_entry(entry)
        next unless payload

        subscribe(seg: payload[:segment], sid: payload[:security_id])
      end

      self
    end

    # Subscribe using an instrument-like object that exposes the helpers
    def subscribe_instrument(instrument)
      payload = extract_subscription_payload(instrument)
      return false unless payload

      subscribe(seg: payload[:segment], sid: payload[:security_id])
      true
    end

    # Unsubscribe using an instrument-like object that exposes the helpers
    def unsubscribe_instrument(instrument)
      payload = extract_subscription_payload(instrument)
      return false unless payload

      unsubscribe(seg: payload[:segment], sid: payload[:security_id])
      true
    end

    # Register per-app tick listener (non-blocking please)
    def on_tick(&blk)
      @handlers << blk
      self
    end

    # Subscribe all currently-open positions (call on boot if desired)
    def subscribe_from_open_positions!
      Position.where(status: %w[OPEN ACTIVE LIVE]).pluck(:exchange_segment, :security_id).each do |seg, sid|
        subscribe(seg: seg, sid: sid.to_s)
      end
      self
    end

    def attach_exit_engine!
      return if @exit_hook_attached

      on_tick do |t|
        Execution::Supervisor.instance.on_tick(t) if t[:segment] == 'NSE_FNO' && t[:security_id] && t[:ltp]
      end

      @exit_hook_attached = true
    end

    private

    def handle_tick(t)
      TickCache.put(t) # global last-known tick
      begin
        ActiveSupport::Notifications.instrument('tick.dhanhq', tick: t)
      rescue StandardError
        nil
      end
      # Local handlers
      @handlers.each do |h|
        h.call(t)
      rescue StandardError
        nil
      end
    end

    def extract_subscription_payload(instrument)
      return unless instrument

      if instrument.respond_to?(:ws_subscription_payload)
        instrument.ws_subscription_payload
      elsif instrument.respond_to?(:exchange_segment) && instrument.respond_to?(:security_id)
        {
          segment: instrument.exchange_segment,
          security_id: instrument.security_id.to_s
        }
      end
    rescue StandardError => e
      Rails.logger.warn("[WsHub] failed to extract payload from #{instrument.class}: #{e.message}")
      nil
    end

    def normalize_subscription_entry(entry)
      case entry
      when nil
        nil
      when Hash
        segment =
          entry[:segment] || entry['segment'] ||
          entry[:exchange_segment] || entry['exchange_segment'] ||
          entry[:ExchangeSegment] || entry['ExchangeSegment']
        security_id =
          entry[:security_id] || entry['security_id'] ||
          entry[:securityId] || entry['securityId'] ||
          entry[:SecurityId] || entry['SecurityId']

        return unless segment && security_id

        { segment: segment, security_id: security_id.to_s }
      else
        extract_subscription_payload(entry)
      end
    rescue StandardError => e
      Rails.logger.warn("[WsHub] failed to normalize subscription entry #{entry.inspect}: #{e.message}")
      nil
    end

    def k(seg, sid) = "#{seg}:#{sid}"
  end
end
