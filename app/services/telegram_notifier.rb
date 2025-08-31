# frozen_string_literal: true

require 'net/http'
require 'uri'

class TelegramNotifier
  TELEGRAM_API = 'https://api.telegram.org'

  def self.send_message(text, chat_id: nil, **extra_params)
    chat_id ||= ENV.fetch('TELEGRAM_CHAT_ID')
    post('sendMessage', chat_id:, text:, **extra_params)
  end

  def self.send_chat_action(action:, chat_id: nil)
    chat_id ||= ENV.fetch('TELEGRAM_CHAT_ID')
    post('sendChatAction', chat_id:, action:)
  end

  def self.notify_entry(label, price, qty:)
    send_message("✅ ENTRY #{label} @ #{fmt(price)} (qty #{qty})")
  end

  def self.notify_exit(label, price, reason:)
    send_message("🚪 EXIT #{label} @ #{fmt(price)} (#{reason})")
  end

  def self.fmt(n)
    format('%.2f', n.to_f)
  end

  private_class_method def self.post(method, **params)
    uri = URI("#{TELEGRAM_API}/bot#{ENV.fetch('TELEGRAM_BOT_TOKEN')}/#{method}")
    res = Net::HTTP.post_form(uri, params)
    Rails.logger.error("Telegram #{method} failed: #{res.body}") unless res.is_a?(Net::HTTPSuccess)
    res
  rescue StandardError => e
    Rails.logger.error("Telegram #{method} error: #{e.message}")
  end
end
