# frozen_string_literal: true

BOOT_CHECK_COMMANDS = %w[server s console c].freeze

def instrument_check_skip_flag?
  raw = ENV['SKIP_INSTRUMENT_FRESHNESS_CHECK'].to_s.strip.downcase
  %w[1 true yes on].include?(raw)
end

if BOOT_CHECK_COMMANDS.include?(ARGV.first) && !Rails.env.test?
  Rails.application.config.after_initialize do
    next if instrument_check_skip_flag?

    begin
      Instruments::FreshnessChecker.call
    rescue NameError => e
      Rails.logger.warn("[InstrumentFreshnessCheck] Unable to load checker: #{e.class} #{e.message}")
    end
  end
end
