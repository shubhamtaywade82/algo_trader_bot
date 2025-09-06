# frozen_string_literal: true

require 'singleton'

module Execution
  # Singleton that owns all live trackers. Reconciles open positions from broker,
  # (re)subscribes them on WS, and dispatches ticks to the right tracker.
  class Supervisor
    include Singleton

    CACHE_PREFIX = 'pos'

    def boot!
      reconcile_open_positions!

      @boot ||= Concurrent::TimerTask.new(execution_interval: 60) do
        reconcile_open_positions!
      end.tap(&:execute)

      # # Periodic reconcile to catch manual closes or broker-side changes
      # @reconciler_thread ||= Thread.new do
      #   Thread.current.name = begin
      #     'exit_reconciler'
      #   rescue StandardError
      #     nil
      #   end
      #   loop do
      #     sleep 60
      #     reconcile_open_positions!
      #   end
      # end
    end

    # WS tick handler
    def on_tick(t)
      key = key_for(t[:segment], t[:security_id])
      if (tr = trackers[key])
        tr.on_ltp(t[:ltp], t[:ts])
        persist(tr)
      end
    rescue StandardError => e
      Rails.logger.error("[Supervisor] on_tick error #{t.inspect}: #{e.class} #{e.message}")
    end

    # Register a newly opened long options leg
    # attrs: :exchange_segment, :security_id, :side ('BUY'), :quantity, :entry_price, :placed_with_super_order (bool)
    def register_position!(attrs)
      key = key_for(attrs[:exchange_segment], attrs[:security_id])
      trackers[key] ||= build_tracker(attrs).tap do |tr|
        subscribe!(tr.exchange_segment, tr.security_id)
        persist(tr)
      end
    end

    # Unregister leg after exit
    def unregister!(exchange_segment:, security_id:)
      key = key_for(exchange_segment, security_id)
      trackers.delete(key)
      unsubscribe!(exchange_segment, security_id)
      Rails.cache.delete(key_for_cache(exchange_segment, security_id))
    end

    private

    def trackers
      @trackers ||= Concurrent::Map.new
    end

    # Pull open positions from broker and mirror into trackers
    def reconcile_open_positions!
      positions = Array(DhanHQ::Models::Position.active)
      keep_keys = []

      positions.each do |p|
        next unless p.respond_to?(:exchange_segment) && p.exchange_segment.to_s == 'NSE_FNO'
        next unless (p.respond_to?(:instrument_type) && p.instrument_type.to_s == 'OPTION') || true # tolerate missing field

        seg = p.exchange_segment.to_s
        sid = p.security_id.to_s
        keep_keys << key_for(seg, sid)

        qty = (p.respond_to?(:quantity) ? p.quantity : p.try(:net_qty) || 0).to_i
        next if qty <= 0 # only long legs we own

        entry = (p.respond_to?(:average_price) ? p.average_price : p.try(:avg_price) || 0).to_f
        next if entry <= 0.0

        ptype = if p.respond_to?(:product_type)
                  p.product_type
                elsif p.respond_to?(:productType)
                  p.productType
                end

        attrs = {
          exchange_segment: seg,
          security_id: sid,
          side: 'BUY',
          quantity: qty,
          entry_price: entry,
          placed_with_super_order: p.respond_to?(:super_order?) ? !p.super_order?.nil? : false,
          product_type: ptype
        }
        register_position!(attrs)
      end

      # Drop trackers that no longer exist at broker
      (trackers.keys - keep_keys).each { |k| trackers.delete(k) }
    rescue StandardError => e
      Rails.logger.error("[Supervisor] reconcile error: #{e.class} #{e.message}")
    end

    def build_tracker(attrs)
      Execution::PositionTracker.new(
        exchange_segment: attrs[:exchange_segment],
        security_id: attrs[:security_id].to_s,
        side: attrs[:side].to_s,
        quantity: attrs[:quantity].to_i,
        entry_price: attrs[:entry_price].to_f,
        policy: Execution::RiskPolicy.load,
        placed_with_super_order: !attrs[:placed_with_super_order].nil?,
        product_type: attrs[:product_type]
      )
    end

    def subscribe!(segment, security_id)
      Live::WsHub.instance.subscribe(seg: segment, sid: security_id)
    rescue StandardError => e
      Rails.logger.error("[Supervisor] subscribe #{segment}:#{security_id} failed: #{e.message}")
    end

    def unsubscribe!(segment, security_id)
      Live::WsHub.instance.unsubscribe(seg: segment, sid: security_id)
    rescue StandardError => e
      Rails.logger.warn("[Supervisor] unsubscribe #{segment}:#{security_id} failed: #{e.message}")
    end

    def key_for(segment, sid) = "#{segment}:#{sid}"
    def key_for_cache(segment, sid) = "#{CACHE_PREFIX}:#{segment}:#{sid}"

    def persist(tracker)
      Rails.cache.write(
        key_for_cache(tracker.exchange_segment, tracker.security_id),
        tracker.snapshot,
        expires_in: 24.hours
      )
    end
  end
end
