# frozen_string_literal: true

require 'singleton'
require 'concurrent'

module Live
  class WsHub
    include Singleton

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
      list.each { |h| subscribe(seg: h[:segment] || h['segment'], sid: h[:security_id] || h['security_id']) }
      self
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

    def k(seg, sid) = "#{seg}:#{sid}"
  end
end
