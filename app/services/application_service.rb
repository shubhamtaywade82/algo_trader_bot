# frozen_string_literal: true

class ApplicationService
  def self.call(...)
    new(...).call
  end

  private

  # ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
  # 📣 Telegram Integration
  # ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

  def notify_step(step, message = nil)
    notify("🔹 Step: #{step}\n#{message || '...'}", tag: step.to_s.upcase)
  end

  def notify_success(message = '✅ Step completed successfully')
    notify(message, tag: 'SUCCESS')
  end

  def notify_failure(error, step = nil)
    notify("❌ Failure#{" at #{step}" if step}: #{error.class} – #{error.message}", tag: 'FAILURE')
  end

  def notify(message, tag: nil)
    context = "[#{self.class.name}]"
    final_message = tag.present? ? "#{context} [#{tag}] \n\n #{message}" : "#{context} #{message}"
    TelegramNotifier.send_message(final_message)
  rescue StandardError => e
    log_error("Telegram Notify Failed: #{e.class} - #{e.message}")
  end

  def typing_ping
    TelegramNotifier.send_chat_action(chat_id: nil, action: 'typing')
  rescue StandardError => e
    log_error("Telegram Typing Action Failed: #{e.class} - #{e.message}")
  end

  # ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
  # 🧾 Logging Helpers (auto-prefix with class name)
  # ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

  %i[info warn error debug].each do |lvl|
    define_method("log_#{lvl}") do |msg|
      Rails.logger.send(lvl, "[#{self.class.name}] #{msg}")
    end
  end
end