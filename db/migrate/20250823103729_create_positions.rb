class CreatePositions < ActiveRecord::Migration[8.0]
  def change
    create_table :positions do |t|
      t.string  :dhan_client_id
      t.string  :trading_symbol
      t.bigint  :security_id
      t.string  :position_type          # "LONG"|"SHORT"|"CLOSED"
      t.string  :exchange_segment       # "NSE_EQ"|"NSE_FNO"|...

      t.string  :product_type           # "CNC"|"INTRADAY"|...

      t.decimal :buy_avg,     precision: 12, scale: 2
      t.integer :buy_qty,     null: false, default: 0
      t.decimal :cost_price,  precision: 12, scale: 2
      t.decimal :sell_avg,    precision: 12, scale: 2
      t.integer :sell_qty,    null: false, default: 0
      t.integer :net_qty,     null: false, default: 0

      t.decimal :realized_profit,   precision: 14, scale: 2
      t.decimal :unrealized_profit, precision: 14, scale: 2

      t.decimal :rbi_reference_rate, precision: 10, scale: 4
      t.integer :multiplier

      t.integer :carry_forward_buy_qty,  default: 0
      t.integer :carry_forward_sell_qty, default: 0
      t.decimal :carry_forward_buy_value,  precision: 14, scale: 2
      t.decimal :carry_forward_sell_value, precision: 14, scale: 2

      t.integer :day_buy_qty,  default: 0
      t.integer :day_sell_qty, default: 0
      t.decimal :day_buy_value,  precision: 14, scale: 2
      t.decimal :day_sell_value, precision: 14, scale: 2

      t.date    :drv_expiry_date
      t.string  :drv_option_type      # "CALL"|"PUT"
      t.decimal :drv_strike_price, precision: 12, scale: 2

      t.boolean :cross_currency, default: false

      # Local helpers
      t.string  :tradable_type
      t.bigint  :tradable_id
      t.string  :state, default: "OPEN" # OPEN|CLOSED (your internal lifecycle)
      t.decimal :entry_price, precision: 12, scale: 2
      t.decimal :unrealized_pnl, precision: 14, scale: 2

      t.timestamps
    end

    add_index :positions, [:exchange_segment, :security_id, :trading_symbol]
    add_index :positions, :state
    add_index :positions, [:tradable_type, :tradable_id]
  end
end
