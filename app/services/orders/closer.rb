# frozen_string_literal: true

module Orders
  class Closer < ApplicationService
    # Accept either a cached order hash or a client_ref
    def initialize(order: nil, client_ref: nil)
      @order_hash = order || (client_ref && State::OrderCache.get(client_ref))
    end

    def call
      return unless @order_hash&.dig(:broker_order_id)

      DhanHQ::Models::SuperOrder.new(order_id: @order_hash[:broker_order_id]).cancel('ENTRY_LEG')
    rescue StandardError => e
      Rails.logger.warn("[Orders::Closer] cancel failed: #{e.class} #{e.message}")
      false
    end
  end
end