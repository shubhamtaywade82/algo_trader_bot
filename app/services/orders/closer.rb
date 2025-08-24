# app/services/orders/closer.rb
module Orders
  class Closer < ApplicationService
    def initialize(order:)
      @order = order
    end

    def call
      return unless @order&.super_ref.present?

      DhanHQ::SuperOrders.close(super_order_id: @order.super_ref)
      @order.update!(super_status: :closed)
    end
  end
end
