class CreateScalpSessions < ActiveRecord::Migration[8.0]
  def change
    create_table :scalp_sessions do |t|
      t.date :trade_date
      t.decimal :capital, precision: 12, scale: 2
      t.decimal :max_day_loss, precision: 12, scale: 2
      t.decimal :realized_pnl, precision: 12, scale: 2
      t.decimal :equity_peak, precision: 12, scale: 2
      t.integer :trades_count
      t.string :status
      t.jsonb :params

      t.timestamps
    end
  end
end
