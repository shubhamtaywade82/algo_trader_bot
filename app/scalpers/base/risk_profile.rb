# frozen_string_literal: true

require 'concurrent'

module Scalpers
  module Base
    # Centralised intraday risk guard used by both scalpers. Keeps a lightweight
    # set of day-level stats in memory (and Rails.cache for restarts) so that the
    # trading loop can query whether a new entry is permissible.
    class RiskProfile
      STATE_CACHE_KEY = 'scalpers:risk:day_stats'

      DEFAULTS = {
        session_start: '09:15',
        session_end: '15:20',
        max_day_loss_pct: 2.5,
        losers_per_day: 6,
        cooldown_minutes: 5,
        max_consecutive_losses: 3,
        base_capital: 1_000_000.0
      }.freeze

      def initialize(config = {})
        raw_config = config.respond_to?(:to_h) ? config.to_h : {}
        @config = DEFAULTS.merge(raw_config.deep_symbolize_keys)
        @mutex = Mutex.new
        @state = Concurrent::Map.new
        restore_state!
      end

      # Returns [allowed(Boolean), reason(String)]
      def allow_entry?(symbol:, expected_loss_rupees: 0.0)
        return [false, 'session_closed'] unless session_open?
        return [false, 'cooldown_active'] if cooldown_active?(symbol)
        return [false, 'day_down_reached'] if day_down_reached?(expected_loss_rupees: expected_loss_rupees)
        return [false, 'max_losers_reached'] if losers_cap_reached?
        return [false, 'consecutive_losses'] if consecutive_losses_blocked?

        [true, 'ok']
      end

      def register_fill!(symbol:, pnl_rupees: 0.0, timestamp: Time.zone.now)
        @mutex.synchronize do
          day = trading_day(timestamp)
          day_stats = fetch_day_state(day)
          day_stats[:trades] += 1
          day_stats[:realized_pnl] += pnl_rupees.to_f
          if pnl_rupees.to_f.negative?
            day_stats[:losers] += 1
            day_stats[:consecutive_losses] += 1
            day_stats[:last_loss_at] = timestamp
            activate_cooldown!(symbol:, timestamp:)
          else
            day_stats[:consecutive_losses] = 0
          end
          persist_day_state(day, day_stats)
        end
      end

      def reset_for!(day = trading_day)
        persist_day_state(day, default_day_state)
      end

      private

      def session_open?(time = Time.zone.now)
        start_time = parse_time(@config[:session_start], time)
        end_time = parse_time(@config[:session_end], time)
        time >= start_time && time <= end_time
      end

      def day_down_reached?(expected_loss_rupees:)
        cap = day_loss_cap_rupees
        return false if cap <= 0

        stats = fetch_day_state(trading_day)
        projected_loss = stats[:realized_pnl] - expected_loss_rupees.to_f
        projected_loss.abs >= cap
      end

      def losers_cap_reached?
        cap = @config[:losers_per_day].to_i
        return false if cap <= 0

        stats = fetch_day_state(trading_day)
        stats[:losers] >= cap
      end

      def consecutive_losses_blocked?
        cap = @config[:max_consecutive_losses].to_i
        return false if cap <= 0

        stats = fetch_day_state(trading_day)
        stats[:consecutive_losses] >= cap
      end

      def cooldown_active?(symbol)
        cooldowns = @state[:cooldowns] ||= Concurrent::Map.new
        expires_at = cooldowns[symbol]
        return false unless expires_at

        if Time.zone.now >= expires_at
          cooldowns.delete(symbol)
          return false
        end

        true
      end

      def activate_cooldown!(symbol:, timestamp: Time.zone.now)
        cooldowns = @state[:cooldowns] ||= Concurrent::Map.new
        minutes = @config[:cooldown_minutes].to_i
        return if minutes <= 0

        cooldowns[symbol] = timestamp + minutes.minutes
      end

      def day_loss_cap_rupees
        (@config[:base_capital].to_f * @config[:max_day_loss_pct].to_f / 100.0).round(2)
      end

      def fetch_day_state(day)
        @state[:days] ||= Concurrent::Map.new
        @state[:days].compute_if_absent(day) { default_day_state }
      end

      def persist_day_state(day, state)
        @state[:days] ||= Concurrent::Map.new
        @state[:days][day] = state
        persist_state!
      end

      def default_day_state
        { trades: 0, realized_pnl: 0.0, losers: 0, consecutive_losses: 0, last_loss_at: nil }.dup
      end

      def parse_time(str, reference)
        hour, minute = str.to_s.split(':').map(&:to_i)
        Time.zone.local(reference.year, reference.month, reference.day, hour, minute)
      end

      def trading_day(time = Time.zone.now)
        time.to_date
      end

      def persist_state!
        snapshot = {
          days: (@state[:days]&.dup || {}),
          cooldowns: (@state[:cooldowns]&.dup || {})
        }
        Rails.cache.write(STATE_CACHE_KEY, snapshot, expires_in: 10.hours)
      end

      def restore_state!
        snapshot = Rails.cache.read(STATE_CACHE_KEY)
        return unless snapshot

        @state[:days] = Concurrent::Map.new(snapshot[:days] || {})
        @state[:cooldowns] = Concurrent::Map.new(snapshot[:cooldowns] || {})
      end
    end
  end
end
