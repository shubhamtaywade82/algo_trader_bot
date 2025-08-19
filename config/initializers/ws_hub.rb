# frozen_string_literal: true

if ENV['ENABLE_WS'] == 'true'
  cfg = Rails.application.config_for(:dhan_ws)
  Rails.application.config.to_prepare do
    Live::WsHub.instance.start!(mode: (cfg['mode'] || 'quote').to_sym)
    Array(cfg['initial']).each do |h|
      Live::WsHub.instance.subscribe(seg: h[:segment], sid: h[:security_id])
    end
  end

  at_exit do
    Live::WsHub.instance.stop!
  rescue StandardError
    nil
  end
end
