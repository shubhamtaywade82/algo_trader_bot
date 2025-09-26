# frozen_string_literal: true

FactoryBot.define do
  factory :trading_position do
    symbol { 'NIFTY24000CE' }
    quantity { 100 }
    entry_price { 150.0 }
    current_price { 155.0 }
    position_type { 'LONG' }
    strategy { 'OptionsScalper' }
    status { 'OPEN' }
    unrealized_pnl { 500.0 }
    realized_pnl { 0.0 }
    stop_loss { 140.0 }
    take_profit { 170.0 }
    created_at { Time.current }
    updated_at { Time.current }
  end
end
