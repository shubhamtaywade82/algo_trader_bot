# frozen_string_literal: true

# Notification manager to coordinate all notification services
class Notifications::NotificationManager
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :telegram_notifier, default: -> { Notifications::TelegramNotifier.new }
  attribute :enabled, :boolean, default: true
  attribute :notification_queue, default: -> { [] }
  attribute :max_queue_size, :integer, default: 100
  attribute :processing_interval, :integer, default: 5 # seconds

  def initialize(attributes = {})
    super
    @processing_thread = nil
    @processing_active = false
  end

  # Start processing notifications
  def start_processing!
    return false if @processing_active

    @processing_active = true
    @processing_thread = Thread.new do
      processing_loop
    end

    Rails.logger.info 'Notification processing started'
    true
  end

  # Stop processing notifications
  def stop_processing!
    return false unless @processing_active

    @processing_active = false
    @processing_thread&.join(5)

    Rails.logger.info 'Notification processing stopped'
    true
  end

  # Send trade alert
  def send_trade_alert(trade_data)
    return false unless enabled?

    notification = {
      type: 'trade_alert',
      data: trade_data,
      timestamp: Time.current,
      priority: 'high'
    }

    queue_notification(notification)
  end

  # Send position update
  def send_position_update(position)
    return false unless enabled?

    notification = {
      type: 'position_update',
      data: position,
      timestamp: Time.current,
      priority: 'medium'
    }

    queue_notification(notification)
  end

  # Send system notification
  def send_system_notification(type, data = {})
    return false unless enabled?

    notification = {
      type: 'system_notification',
      data: { type: type, data: data },
      timestamp: Time.current,
      priority: 'medium'
    }

    queue_notification(notification)
  end

  # Send daily summary
  def send_daily_summary(summary_data)
    return false unless enabled?

    notification = {
      type: 'daily_summary',
      data: summary_data,
      timestamp: Time.current,
      priority: 'low'
    }

    queue_notification(notification)
  end

  # Send error alert
  def send_error_alert(error_data)
    return false unless enabled?

    notification = {
      type: 'error_alert',
      data: error_data,
      timestamp: Time.current,
      priority: 'high'
    }

    queue_notification(notification)
  end

  # Send risk alert
  def send_risk_alert(risk_data)
    return false unless enabled?

    notification = {
      type: 'risk_alert',
      data: risk_data,
      timestamp: Time.current,
      priority: 'high'
    }

    queue_notification(notification)
  end

  # Get notification statistics
  def notification_stats
    {
      queue_size: @notification_queue.size,
      processing_active: @processing_active,
      telegram_enabled: telegram_notifier.enabled?,
      total_sent: @total_sent || 0,
      total_failed: @total_failed || 0
    }
  end

  private

  def queue_notification(notification)
    return false if @notification_queue.size >= max_queue_size

    @notification_queue << notification
    Rails.logger.debug "Notification queued: #{notification[:type]}"
    true
  end

  def processing_loop
    Rails.logger.info 'Notification processing loop started'

    while @processing_active
      begin
        process_notifications
        sleep(processing_interval)
      rescue StandardError => e
        Rails.logger.error "Notification processing error: #{e.message}"
        sleep(processing_interval * 2)
      end
    end

    Rails.logger.info 'Notification processing loop ended'
  end

  def process_notifications
    return if @notification_queue.empty?

    # Process high priority notifications first
    high_priority = @notification_queue.select { |n| n[:priority] == 'high' }
    medium_priority = @notification_queue.select { |n| n[:priority] == 'medium' }
    low_priority = @notification_queue.select { |n| n[:priority] == 'low' }

    [high_priority, medium_priority, low_priority].flatten.each do |notification|
      process_single_notification(notification)
      @notification_queue.delete(notification)
    end
  end

  def process_single_notification(notification)
    begin
      case notification[:type]
      when 'trade_alert'
        telegram_notifier.send_trade_alert(notification[:data])
      when 'position_update'
        telegram_notifier.send_position_update(notification[:data])
      when 'system_notification'
        telegram_notifier.send_system_notification(
          notification[:data][:type],
          notification[:data][:data]
        )
      when 'daily_summary'
        telegram_notifier.send_daily_summary(notification[:data])
      when 'error_alert'
        telegram_notifier.send_error_alert(notification[:data])
      when 'risk_alert'
        telegram_notifier.send_risk_alert(notification[:data])
      end

      @total_sent = (@total_sent || 0) + 1
      Rails.logger.debug "Notification sent: #{notification[:type]}"

    rescue StandardError => e
      @total_failed = (@total_failed || 0) + 1
      Rails.logger.error "Failed to send notification #{notification[:type]}: #{e.message}"
    end
  end
end
