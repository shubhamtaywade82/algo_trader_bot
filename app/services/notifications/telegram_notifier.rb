# frozen_string_literal: true

# Telegram notifier service for sending trade alerts and system notifications
class Notifications::TelegramNotifier
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :bot_token, :string
  attribute :chat_id, :string
  attribute :enabled, :boolean, default: true
  attribute :retry_attempts, :integer, default: 3
  attribute :retry_delay, :integer, default: 1 # seconds

  def initialize(attributes = {})
    super
    @bot_token ||= ENV.fetch('TELEGRAM_BOT_TOKEN', nil)
    @chat_id ||= ENV.fetch('TELEGRAM_CHAT_ID', nil)
  end

  # Send a trade alert
  def send_trade_alert(trade_data)
    return false unless enabled? && valid_config?

    message = build_trade_alert_message(trade_data)
    send_message(message, parse_mode: 'HTML')
  end

  # Send a position update
  def send_position_update(position)
    return false unless enabled? && valid_config?

    message = build_position_update_message(position)
    send_message(message, parse_mode: 'HTML')
  end

  # Send a system notification
  def send_system_notification(type, data = {})
    return false unless enabled? && valid_config?

    message = build_system_notification_message(type, data)
    send_message(message, parse_mode: 'HTML')
  end

  # Send a daily summary
  def send_daily_summary(summary_data)
    return false unless enabled? && valid_config?

    message = build_daily_summary_message(summary_data)
    send_message(message, parse_mode: 'HTML')
  end

  # Send an error alert
  def send_error_alert(error_data)
    return false unless enabled? && valid_config?

    message = build_error_alert_message(error_data)
    send_message(message, parse_mode: 'HTML')
  end

  # Send a risk alert
  def send_risk_alert(risk_data)
    return false unless enabled? && valid_config?

    message = build_risk_alert_message(risk_data)
    send_message(message, parse_mode: 'HTML')
  end

  # Test the Telegram connection
  def test_connection
    return { success: false, error: 'Not enabled' } unless enabled?
    return { success: false, error: 'Invalid configuration' } unless valid_config?

    begin
      response = make_telegram_request('getMe')
      { success: true, data: response }
    rescue StandardError => e
      { success: false, error: e.message }
    end
  end

  private

  def enabled?
    enabled && bot_token.present? && chat_id.present?
  end

  def valid_config?
    bot_token.present? && chat_id.present?
  end

  def send_message(text, options = {})
    return false unless enabled? && valid_config?

    payload = {
      chat_id: chat_id,
      text: text,
      disable_web_page_preview: true
    }.merge(options)

    retry_with_backoff do
      response = make_telegram_request('sendMessage', payload)
      response['ok'] == true
    end
  end

  def make_telegram_request(method, payload = {})
    uri = URI("https://api.telegram.org/bot#{bot_token}/#{method}")

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 10
    http.open_timeout = 10

    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'
    request.body = payload.to_json

    response = http.request(request)
    JSON.parse(response.body)
  end

  def retry_with_backoff
    attempts = 0
    begin
      yield
    rescue StandardError => e
      attempts += 1
      if attempts < retry_attempts
        sleep(retry_delay * attempts)
        retry
      else
        Rails.logger.error "Telegram notification failed after #{attempts} attempts: #{e.message}"
        false
      end
    end
  end

  def build_trade_alert_message(trade_data)
    emoji = trade_data[:side] == 'BUY' ? '🟢' : '🔴'
    action = trade_data[:side] == 'BUY' ? 'BOUGHT' : 'SOLD'

    <<~MESSAGE
      #{emoji} <b>TRADE #{action}</b>

      📊 <b>Instrument:</b> #{trade_data[:instrument]}
      💰 <b>Price:</b> ₹#{trade_data[:price]}
      📈 <b>Quantity:</b> #{trade_data[:quantity]}
      🎯 <b>Strategy:</b> #{trade_data[:strategy]}
      ⚡ <b>Confidence:</b> #{(trade_data[:confidence] * 100).round(1)}%

      🛡️ <b>Stop Loss:</b> ₹#{trade_data[:stop_loss]}
      🎯 <b>Take Profit:</b> ₹#{trade_data[:take_profit]}

      ⏰ <b>Time:</b> #{Time.current.strftime('%H:%M:%S')}
    MESSAGE
  end

  def build_position_update_message(position)
    pnl_emoji = position[:current_pnl] >= 0 ? '📈' : '📉'
    pnl_color = position[:current_pnl] >= 0 ? '🟢' : '🔴'

    <<~MESSAGE
      #{pnl_emoji} <b>POSITION UPDATE</b>

      📊 <b>Instrument:</b> #{position[:instrument]}
      💰 <b>Entry Price:</b> ₹#{position[:entry_price]}
      📊 <b>Current Price:</b> ₹#{position[:current_price]}
      #{pnl_color} <b>P&L:</b> ₹#{position[:current_pnl].round(2)}
      📊 <b>% Change:</b> #{position[:percentage_pnl].round(2)}%

      🛡️ <b>Stop Loss:</b> ₹#{position[:stop_loss]}
      🎯 <b>Take Profit:</b> ₹#{position[:take_profit]}

      ⏰ <b>Duration:</b> #{position[:duration_hours].round(1)}h
    MESSAGE
  end

  def build_system_notification_message(type, data)
    case type
    when 'trading_started'
      <<~MESSAGE
        🚀 <b>TRADING STARTED</b>

        ⏰ <b>Time:</b> #{Time.current.strftime('%H:%M:%S')}
        📊 <b>Instruments:</b> #{data[:instruments_count]}
        🎯 <b>Strategies:</b> #{data[:strategies_count]}
      MESSAGE
    when 'trading_stopped'
      <<~MESSAGE
        🛑 <b>TRADING STOPPED</b>

        ⏰ <b>Time:</b> #{Time.current.strftime('%H:%M:%S')}
        📊 <b>Reason:</b> #{data[:reason]}
      MESSAGE
    when 'position_opened'
      <<~MESSAGE
        ➕ <b>POSITION OPENED</b>

        📊 <b>Instrument:</b> #{data[:instrument]}
        💰 <b>Price:</b> ₹#{data[:price]}
        📈 <b>Quantity:</b> #{data[:quantity]}
      MESSAGE
    when 'position_closed'
      <<~MESSAGE
        ➖ <b>POSITION CLOSED</b>

        📊 <b>Instrument:</b> #{data[:instrument]}
        💰 <b>Exit Price:</b> ₹#{data[:exit_price]}
        📊 <b>P&L:</b> ₹#{data[:pnl].round(2)}
        📊 <b>Reason:</b> #{data[:reason]}
      MESSAGE
    else
      <<~MESSAGE
        🔔 <b>SYSTEM NOTIFICATION</b>

        📊 <b>Type:</b> #{type}
        📊 <b>Data:</b> #{data.to_json}
        ⏰ <b>Time:</b> #{Time.current.strftime('%H:%M:%S')}
      MESSAGE
    end
  end

  def build_daily_summary_message(summary_data)
    <<~MESSAGE
      📊 <b>DAILY SUMMARY</b>

      📈 <b>Total Trades:</b> #{summary_data[:total_trades]}
      💰 <b>Total P&L:</b> ₹#{summary_data[:total_pnl].round(2)}
      📊 <b>Win Rate:</b> #{summary_data[:win_rate].round(1)}%
      🎯 <b>Best Trade:</b> ₹#{summary_data[:best_trade].round(2)}
      📉 <b>Worst Trade:</b> ₹#{summary_data[:worst_trade].round(2)}

      📊 <b>Active Positions:</b> #{summary_data[:active_positions]}
      🛡️ <b>Max Drawdown:</b> #{summary_data[:max_drawdown].round(2)}%

      ⏰ <b>Session Time:</b> #{summary_data[:session_time]}h
      📊 <b>Date:</b> #{Date.current.strftime('%Y-%m-%d')}
    MESSAGE
  end

  def build_error_alert_message(error_data)
    <<~MESSAGE
      🚨 <b>ERROR ALERT</b>

      📊 <b>Error:</b> #{error_data[:error]}
      📊 <b>Component:</b> #{error_data[:component]}
      📊 <b>Severity:</b> #{error_data[:severity]}

      📊 <b>Details:</b> #{error_data[:details]}
      ⏰ <b>Time:</b> #{Time.current.strftime('%H:%M:%S')}
    MESSAGE
  end

  def build_risk_alert_message(risk_data)
    <<~MESSAGE
      ⚠️ <b>RISK ALERT</b>

      📊 <b>Type:</b> #{risk_data[:type]}
      📊 <b>Level:</b> #{risk_data[:level]}
      📊 <b>Current:</b> #{risk_data[:current].round(2)}%
      📊 <b>Limit:</b> #{risk_data[:limit].round(2)}%

      📊 <b>Position:</b> #{risk_data[:position]}
      📊 <b>Action:</b> #{risk_data[:action]}

      ⏰ <b>Time:</b> #{Time.current.strftime('%H:%M:%S')}
    MESSAGE
  end
end
