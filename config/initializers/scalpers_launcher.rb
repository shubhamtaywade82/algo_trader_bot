# frozen_string_literal: true

Rails.application.config.after_initialize do
  next unless defined?(Rails::Server)

  Scalpers::Launcher.start_enabled(async: true)
end
