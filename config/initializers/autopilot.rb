# frozen_string_literal: true

# Autopilot Initializer
# Starts the autopilot service when Rails boots

Rails.application.configure do
  config.after_initialize do
    # Only start autopilot in development and production
    if Rails.env.development? || Rails.env.production?
      begin
        autopilot = Autopilot::Manager.new

        if autopilot.start
          Rails.logger.info('[Autopilot] Successfully started autopilot service')

          # Store reference for potential use in console or other parts
          Rails.application.config.autopilot_manager = autopilot
        else
          Rails.logger.warn('[Autopilot] Failed to start autopilot service')
        end
      rescue StandardError => e
        Rails.logger.error("[Autopilot] Error starting autopilot: #{e.message}")
      end
    end
  end
end

# Graceful shutdown
at_exit do
  if Rails.application.config.respond_to?(:autopilot_manager) &&
     Rails.application.config.autopilot_manager&.running?
    Rails.logger.info('[Autopilot] Shutting down autopilot service...')
    Rails.application.config.autopilot_manager.stop!
  end
end
