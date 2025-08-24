class CreateHoldings < ActiveRecord::Migration[8.0]
  def change
    create_table :holdings do |t|
      t.string  :exchange                     # "ALL" per API
      t.string  :trading_symbol
      t.bigint  :security_id
      t.string  :isin

      t.integer :total_qty,       null: false, default: 0
      t.integer :dp_qty,          null: false, default: 0
      t.integer :t1_qty,          null: false, default: 0
      t.integer :available_qty,   null: false, default: 0
      t.integer :collateral_qty,  null: false, default: 0

      t.decimal :avg_cost_price,  precision: 12, scale: 2

      t.timestamps
    end

    add_index :holdings, [:exchange, :security_id, :trading_symbol]
  end
end
