class CreatePositionsForTrading < ActiveRecord::Migration[8.0]
  def change
    create_table :trading_positions do |t|
      # Basic position info
      t.references :instrument, null: false, foreign_key: true
      t.string :strategy, null: false
      t.string :side, null: false # BUY or SELL
      t.integer :quantity, null: false
      t.decimal :entry_price, precision: 12, scale: 2, null: false
      t.decimal :current_price, precision: 12, scale: 2

      # Risk management
      t.decimal :stop_loss, precision: 12, scale: 2
      t.decimal :take_profit, precision: 12, scale: 2
      t.decimal :risk_per_trade, precision: 8, scale: 4, default: 0.02
      t.decimal :risk_reward_ratio, precision: 8, scale: 2, default: 2.0

      # P&L tracking
      t.decimal :expected_profit, precision: 14, scale: 2
      t.decimal :expected_loss, precision: 14, scale: 2
      t.decimal :current_pnl, precision: 14, scale: 2, default: 0.0
      t.decimal :max_profit, precision: 14, scale: 2, default: 0.0
      t.decimal :max_loss, precision: 14, scale: 2, default: 0.0

      # Position status
      t.string :status, default: 'active' # active, closed, cancelled
      t.decimal :confidence, precision: 3, scale: 2, default: 0.5
      t.string :exit_reason
      t.decimal :exit_price, precision: 12, scale: 2
      t.datetime :exit_time

      # Order tracking
      t.string :order_id
      t.string :client_ref
      t.string :dhan_order_id

      # Time tracking
      t.datetime :entry_time, null: false
      t.datetime :last_update_time
      t.integer :duration_minutes, default: 0

      # Risk management flags
      t.boolean :stop_loss_hit, default: false
      t.boolean :take_profit_hit, default: false
      t.boolean :time_exit_triggered, default: false
      t.boolean :risk_exit_triggered, default: false

      # Trailing stop management
      t.decimal :trailing_stop_price, precision: 12, scale: 2
      t.decimal :trailing_stop_percentage, precision: 5, scale: 2
      t.boolean :trailing_stop_active, default: false

      # Portfolio context
      t.decimal :portfolio_allocation, precision: 8, scale: 4
      t.decimal :daily_pnl_contribution, precision: 14, scale: 2, default: 0.0

      t.timestamps

      # Indexes
      t.index [:instrument_id, :status]
      t.index [:strategy, :status]
      t.index [:entry_time]
      t.index [:status, :entry_time]
      t.index [:client_ref], unique: true
    end
  end
end
