# frozen_string_literal: true

if ENV['ENABLE_WS'] == 'true'
  cfg = Rails.application.config_for(:dhan_ws)

  Rails.application.config.to_prepare do
    hub = Live::WsHub.instance
    hub.start!(mode: (cfg['mode'] || 'quote').to_sym)

    hub.attach_exit_engine! # clean, idempotent

    Array(cfg['initial']).each do |h|
      hub.subscribe(seg: h[:segment], sid: h[:security_id])
    end

    Execution::Supervisor.instance.boot!
  end

  at_exit do
    Live::WsHub.instance.stop!
  rescue StandardError
    nil
  end
end