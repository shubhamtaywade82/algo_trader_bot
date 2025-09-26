# frozen_string_literal: true

module Instruments
  class FreshnessChecker < ApplicationService
    DEFAULT_STALE_HOURS = ENV.fetch('INSTRUMENTS_STALE_AFTER_HOURS', '24').to_i

    def initialize(stdout: $stdout, logger: Rails.logger)
      @stdout = stdout
      @logger = logger
      @threshold = DEFAULT_STALE_HOURS.hours
    end

    def call
      return if skip?
      return unless tables_present?

      if missing_records?
        alert!("Instrument master is empty. Run `bundle exec rake instruments:import` before trading.")
        return
      end

      if stale_records?
        stamp = freshness_timestamp&.iso8601 || 'unknown time'
        alert!("Instrument master last updated at #{stamp}. Run `bundle exec rake instruments:import` to refresh.")
      elsif stale_cache_file?
        alert!("Instrument CSV cache at #{cache_path} is older than #{@threshold.inspect}. Consider re-running the import task.")
      else
        @logger.debug('[Instruments::FreshnessChecker] Instrument universe is fresh enough.')
      end
    rescue ActiveRecord::NoDatabaseError, ActiveRecord::StatementInvalid
      # Database not ready (e.g., during setup) → skip quietly
    rescue StandardError => e
      @logger.warn("[Instruments::FreshnessChecker] check failed: #{e.class} #{e.message}")
    end

    private

    def skip?
      raw = ENV['SKIP_INSTRUMENT_FRESHNESS_CHECK'].to_s.strip.downcase
      %w[1 true yes on].include?(raw)
    end

    def tables_present?
      conn = ActiveRecord::Base.connection
      conn.data_source_exists?(:instruments) && conn.data_source_exists?(:derivatives)
    end

    def missing_records?
      !Instrument.exists? && !Derivative.exists?
    end

    def stale_records?
      return true unless freshness_timestamp

      freshness_timestamp < cutoff_time
    end

    def freshness_timestamp
      @freshness_timestamp ||= [Instrument.maximum(:updated_at), Derivative.maximum(:updated_at)].compact.max
    end

    def stale_cache_file?
      return false unless cache_path.exist?

      cache_path.mtime < cutoff_time
    end

    def cache_path
      InstrumentsImporter::CACHE_PATH
    end

    def cutoff_time
      Time.current - @threshold
    end

    def alert!(message)
      formatted = "⚠️  #{message}"
      @stdout.puts(formatted)
      @logger.warn("[Instruments::FreshnessChecker] #{message}")
    end
  end
end
