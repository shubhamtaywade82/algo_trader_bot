class CreateScalpSessions < ActiveRecord::Migration[8.0]
  def change
    create_table :scalp_sessions do |t|
      t.date     :trade_date, null: false
      t.decimal  :capital, precision: 12, scale: 2, null: false, default: 0.0
      t.decimal  :max_day_loss, precision: 12, scale: 2, null: false, default: 0.0
      t.decimal  :realized_pnl, precision: 12, scale: 2, null: false, default: 0.0
      t.decimal  :equity_peak, precision: 12, scale: 2, null: false, default: 0.0
      t.integer  :trades_count, null: false, default: 0
      t.string   :status, null: false, default: "idle" # idle|running|stopped|killed
      t.jsonb    :params, null: false, default: {}

      t.timestamps
    end
  end
end
