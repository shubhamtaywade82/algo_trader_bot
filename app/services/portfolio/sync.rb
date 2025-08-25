module Portfolio
  class Sync < ApplicationService
    def call
      sync_holdings
      sync_positions
    end

    def sync_holdings
      arr = DhanHQ::Models::Holding.all # => array of hashes per API
      Array(arr).each do |h|
        Holding
          .find_or_initialize_by(exchange: h.exchange, security_id: h.security_id)
          .update!(
            trading_symbol: h.trading_symbol,
            isin: h.isin,
            total_qty: h.total_qty,
            dp_qty: h.dp_qty,
            t1_qty: h.t1_qty,
            available_qty: h.available_qty,
            collateral_qty: h.collateral_qty,
            avg_cost_price: h.avg_cost_price
          )
      end
    rescue DhanHQ::InternalServerError => e
      Rails.logger.error("Failed to sync holdings: #{e.message}")
      []
    end

    def sync_positions
      arr = DhanHQ::Models::Position.all

      Array(arr).each do |p|
        Position
          .find_or_initialize_by(exchange_segment: p.exchange_segment, security_id: p.security_id)
          .update!(
            dhan_client_id: p.dhan_client_id,
            trading_symbol: p.trading_symbol,
            position_type: p.position_type,
            product_type: p.product_type,
            buy_avg: p.buy_avg,
            buy_qty: p.buy_qty,
            cost_price: p.cost_price,
            sell_avg: p.sell_avg,
            sell_qty: p.sell_qty,
            net_qty: p.net_qty,
            realized_profit: p.realized_profit,
            unrealized_profit: p.unrealized_profit,
            rbi_reference_rate: p.rbi_reference_rate,
            multiplier: p.multiplier,
            carry_forward_buy_qty: p.carry_forward_buy_qty,
            carry_forward_sell_qty: p.carry_forward_sell_qty,
            carry_forward_buy_value: p.carry_forward_buy_value,
            carry_forward_sell_value: p.carry_forward_sell_value,
            day_buy_qty: p.day_buy_qty,
            day_sell_qty: p.day_sell_qty,
            day_buy_value: p.day_buy_value,
            day_sell_value: p.day_sell_value,
            drv_expiry_date: begin
              Date.parse(p.drv_expiry_date)
            rescue StandardError
              nil
            end,
            drv_option_type: p.drv_option_type,
            drv_strike_price: p.drv_strike_price,
            cross_currency: p.cross_currency
          )
      end
    end
  end
end