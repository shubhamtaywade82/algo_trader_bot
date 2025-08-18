module Scalp
  class CloseStrikesManager
    class << self
      def start(roster)
        @mutex ||= Mutex.new
        @started = true
        @subscribed = Set.new # holds "SEGMENT:SECURITY_ID" keys
        @roster = Array(roster)

        # subscribe underlyings up front (indices/stocks)
        @roster.each { |symbol| subscribe_underlying!(symbol) }
      rescue StandardError => e
        Rails.logger.error("[CloseStrikesManager] start failed: #{e.class}: #{e.message}")
      end

      def stop
        @started = false
        # Optional: perform a bulk UNSUB here if you want to clean everything
        # unsubscribe_all!
      rescue StandardError => e
        Rails.logger.error("[CloseStrikesManager] stop failed: #{e.class}: #{e.message}")
      end

      # Subscribe option legs for a given symbol (e.g., ATM ± 1)
      # Pass an array of [segment, security_id] pairs or Derivative records.
      def subscribe_legs!(legs)
        return unless @started

        pairs = normalize_pairs(legs)
        with_client do |client|
          to_add = filter_new(pairs)
          chunked(to_add, 90).each do |batch|
            client.subscribe_many(:quote, batch) # or :full if you want depth/OI
            mark_subscribed(batch)
          rescue StandardError => e
            Rails.logger.warn("[CloseStrikesManager] subscribe_many failed: #{e.class}: #{e.message}")
          end
        end
      end

      # Called by PositionGuard after exit; real impl can ref-count and UNSUB.
      def unsubscribe_if_unused(segment, security_id)
        # Optional: track refs per leg and UNSUB when count goes zero.
        # For now, we keep them subscribed; DhanHQ allows <=100 per frame and
        # we aim to stay within that via focused ATM±1 usage.
        true
      end

      # Convenience for subscribing a single leg (Derivative or [seg, id])
      def subscribe_leg!(leg)
        subscribe_legs!([leg])
      end

      private

      # Subscribe the underlying itself so we can watch spot drift if desired
      def subscribe_underlying!(symbol)
        inst = Instrument.find_by(symbol: symbol) || Instrument.find_by(tradingsymbol: symbol)
        return unless inst

        segment = inst.exchange_segment # e.g., "NSE_FNO" for index futures; adjust per your mapping
        sec_id  = inst.security_id
        return unless segment.present? && sec_id.present?

        subscribe_legs!([[segment, sec_id]])
      end

      def with_client
        # Try to get the running WS client from your supervisor or directly:
        client = (WSSupervisor.respond_to?(:client) && WSSupervisor.client) ||
                 (defined?(DhanHQ::WS::Client) && DhanHQ::WS::Client.try(:current)) ||
                 (defined?(DhanHQ::WS::Client) && DhanHQ::WS::Client.try(:instance))

        unless client
          Rails.logger.warn('[CloseStrikesManager] WS client not available yet')
          return
        end
        yield client
      end

      def normalize_pairs(legs)
        legs.filter_map do |leg|
          case leg
          when Array
            seg, id = leg
            next unless seg && id

            [seg.to_s, id.to_i]
          else
            # treat as Derivative or a PORO responding to segment/security_id
            seg = leg.respond_to?(:exchange_segment) ? leg.exchange_segment : leg.segment
            id  = leg.respond_to?(:security_id) ? leg.security_id : leg.id
            next unless seg && id

            [seg.to_s, id.to_i]
          end
        end
      end

      def filter_new(pairs)
        @mutex.synchronize do
          pairs.reject { |seg, id| @subscribed.include?("#{seg}:#{id}") }
        end
      end

      def mark_subscribed(pairs)
        @mutex.synchronize do
          pairs.each { |seg, id| @subscribed.add("#{seg}:#{id}") }
        end
      end

      def chunked(arr, size)
        arr.each_slice(size).to_a
      end

      # If you later implement hard UNSUB:
      # def unsubscribe_all!
      #   with_client do |client|
      #     keys = @mutex.synchronize { @subscribed.to_a }
      #     pairs = keys.map { |k| seg, id = k.split(":"); [seg, id.to_i] }
      #     chunked(pairs, 90).each { |batch| client.unsubscribe_many(:quote, batch) }
      #   end
      #   @mutex.synchronize { @subscribed.clear }
      # end
    end
  end
end