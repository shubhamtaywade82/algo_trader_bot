# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_09_06_090659) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "delayed_jobs", force: :cascade do |t|
    t.integer "priority", default: 0, null: false
    t.integer "attempts", default: 0, null: false
    t.text "handler", null: false
    t.text "last_error"
    t.datetime "run_at"
    t.datetime "locked_at"
    t.datetime "failed_at"
    t.string "locked_by"
    t.string "queue"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["priority", "run_at"], name: "delayed_jobs_priority"
  end

  create_table "derivatives", force: :cascade do |t|
    t.bigint "instrument_id", null: false
    t.string "exchange"
    t.string "segment"
    t.string "security_id"
    t.string "isin"
    t.string "instrument_code"
    t.string "underlying_security_id"
    t.string "underlying_symbol"
    t.string "symbol_name"
    t.string "display_name"
    t.string "instrument_type"
    t.string "series"
    t.integer "lot_size"
    t.date "expiry_date"
    t.decimal "strike_price"
    t.string "option_type"
    t.decimal "tick_size"
    t.string "expiry_flag"
    t.string "bracket_flag"
    t.string "cover_flag"
    t.string "asm_gsm_flag"
    t.string "asm_gsm_category"
    t.string "buy_sell_indicator"
    t.decimal "buy_co_min_margin_per"
    t.decimal "sell_co_min_margin_per"
    t.decimal "buy_co_sl_range_max_perc"
    t.decimal "sell_co_sl_range_max_perc"
    t.decimal "buy_co_sl_range_min_perc"
    t.decimal "sell_co_sl_range_min_perc"
    t.decimal "buy_bo_min_margin_per"
    t.decimal "sell_bo_min_margin_per"
    t.decimal "buy_bo_sl_range_max_perc"
    t.decimal "sell_bo_sl_range_max_perc"
    t.decimal "buy_bo_sl_range_min_perc"
    t.decimal "sell_bo_sl_min_range"
    t.decimal "buy_bo_profit_range_max_perc"
    t.decimal "sell_bo_profit_range_max_perc"
    t.decimal "buy_bo_profit_range_min_perc"
    t.decimal "sell_bo_profit_range_min_perc"
    t.decimal "mtf_leverage"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["instrument_code"], name: "index_derivatives_on_instrument_code"
    t.index ["instrument_id"], name: "index_derivatives_on_instrument_id"
    t.index ["security_id", "symbol_name", "exchange", "segment"], name: "index_derivatives_unique", unique: true
    t.index ["symbol_name"], name: "index_derivatives_on_symbol_name"
    t.index ["underlying_symbol", "expiry_date"], name: "index_derivatives_on_underlying_symbol_and_expiry_date", where: "(underlying_symbol IS NOT NULL)"
  end

  create_table "holdings", force: :cascade do |t|
    t.string "exchange"
    t.string "trading_symbol"
    t.bigint "security_id"
    t.string "isin"
    t.integer "total_qty", default: 0, null: false
    t.integer "dp_qty", default: 0, null: false
    t.integer "t1_qty", default: 0, null: false
    t.integer "available_qty", default: 0, null: false
    t.integer "collateral_qty", default: 0, null: false
    t.decimal "avg_cost_price", precision: 12, scale: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["exchange", "security_id", "trading_symbol"], name: "index_holdings_on_exchange_and_security_id_and_trading_symbol"
  end

  create_table "instruments", force: :cascade do |t|
    t.string "exchange", null: false
    t.string "segment", null: false
    t.string "security_id", null: false
    t.string "isin"
    t.string "instrument_code"
    t.string "underlying_security_id"
    t.string "underlying_symbol"
    t.string "symbol_name"
    t.string "display_name"
    t.string "instrument_type"
    t.string "series"
    t.integer "lot_size"
    t.date "expiry_date"
    t.decimal "strike_price", precision: 15, scale: 5
    t.string "option_type"
    t.decimal "tick_size"
    t.string "expiry_flag"
    t.string "bracket_flag"
    t.string "cover_flag"
    t.string "asm_gsm_flag"
    t.string "asm_gsm_category"
    t.string "buy_sell_indicator"
    t.decimal "buy_co_min_margin_per", precision: 8, scale: 2
    t.decimal "sell_co_min_margin_per", precision: 8, scale: 2
    t.decimal "buy_co_sl_range_max_perc", precision: 8, scale: 2
    t.decimal "sell_co_sl_range_max_perc", precision: 8, scale: 2
    t.decimal "buy_co_sl_range_min_perc", precision: 8, scale: 2
    t.decimal "sell_co_sl_range_min_perc", precision: 8, scale: 2
    t.decimal "buy_bo_min_margin_per", precision: 8, scale: 2
    t.decimal "sell_bo_min_margin_per", precision: 8, scale: 2
    t.decimal "buy_bo_sl_range_max_perc", precision: 8, scale: 2
    t.decimal "sell_bo_sl_range_max_perc", precision: 8, scale: 2
    t.decimal "buy_bo_sl_range_min_perc", precision: 8, scale: 2
    t.decimal "sell_bo_sl_min_range", precision: 8, scale: 2
    t.decimal "buy_bo_profit_range_max_perc", precision: 8, scale: 2
    t.decimal "sell_bo_profit_range_max_perc", precision: 8, scale: 2
    t.decimal "buy_bo_profit_range_min_perc", precision: 8, scale: 2
    t.decimal "sell_bo_profit_range_min_perc", precision: 8, scale: 2
    t.decimal "mtf_leverage", precision: 8, scale: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["instrument_code"], name: "index_instruments_on_instrument_code"
    t.index ["security_id", "symbol_name", "exchange", "segment"], name: "index_instruments_unique", unique: true
    t.index ["symbol_name"], name: "index_instruments_on_symbol_name"
    t.index ["underlying_symbol", "expiry_date"], name: "index_instruments_on_underlying_symbol_and_expiry_date", where: "(underlying_symbol IS NOT NULL)"
  end

  create_table "positions", force: :cascade do |t|
    t.string "dhan_client_id"
    t.string "trading_symbol"
    t.bigint "security_id"
    t.string "position_type"
    t.string "exchange_segment"
    t.string "product_type"
    t.decimal "buy_avg", precision: 12, scale: 2
    t.integer "buy_qty", default: 0, null: false
    t.decimal "cost_price", precision: 12, scale: 2
    t.decimal "sell_avg", precision: 12, scale: 2
    t.integer "sell_qty", default: 0, null: false
    t.integer "net_qty", default: 0, null: false
    t.decimal "realized_profit", precision: 14, scale: 2
    t.decimal "unrealized_profit", precision: 14, scale: 2
    t.decimal "rbi_reference_rate", precision: 10, scale: 4
    t.integer "multiplier"
    t.integer "carry_forward_buy_qty", default: 0
    t.integer "carry_forward_sell_qty", default: 0
    t.decimal "carry_forward_buy_value", precision: 14, scale: 2
    t.decimal "carry_forward_sell_value", precision: 14, scale: 2
    t.integer "day_buy_qty", default: 0
    t.integer "day_sell_qty", default: 0
    t.decimal "day_buy_value", precision: 14, scale: 2
    t.decimal "day_sell_value", precision: 14, scale: 2
    t.date "drv_expiry_date"
    t.string "drv_option_type"
    t.decimal "drv_strike_price", precision: 12, scale: 2
    t.boolean "cross_currency", default: false
    t.string "tradable_type"
    t.bigint "tradable_id"
    t.string "state", default: "OPEN"
    t.decimal "entry_price", precision: 12, scale: 2
    t.decimal "unrealized_pnl", precision: 14, scale: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["exchange_segment", "security_id", "trading_symbol"], name: "idx_on_exchange_segment_security_id_trading_symbol_87deb66c05"
    t.index ["state"], name: "index_positions_on_state"
    t.index ["tradable_type", "tradable_id"], name: "index_positions_on_tradable_type_and_tradable_id"
  end

  create_table "scalp_sessions", force: :cascade do |t|
    t.date "trade_date", null: false
    t.decimal "capital", precision: 12, scale: 2, default: "0.0", null: false
    t.decimal "max_day_loss", precision: 12, scale: 2, default: "0.0", null: false
    t.decimal "realized_pnl", precision: 12, scale: 2, default: "0.0", null: false
    t.decimal "equity_peak", precision: 12, scale: 2, default: "0.0", null: false
    t.integer "trades_count", default: 0, null: false
    t.string "status", default: "idle", null: false
    t.jsonb "params", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "settings", force: :cascade do |t|
    t.string "key", null: false
    t.text "value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_settings_on_key", unique: true
  end

  create_table "trading_positions", force: :cascade do |t|
    t.bigint "instrument_id", null: false
    t.string "strategy", null: false
    t.string "side", null: false
    t.integer "quantity", null: false
    t.decimal "entry_price", precision: 12, scale: 2, null: false
    t.decimal "current_price", precision: 12, scale: 2
    t.decimal "stop_loss", precision: 12, scale: 2
    t.decimal "take_profit", precision: 12, scale: 2
    t.decimal "risk_per_trade", precision: 8, scale: 4, default: "0.02"
    t.decimal "risk_reward_ratio", precision: 8, scale: 2, default: "2.0"
    t.decimal "expected_profit", precision: 14, scale: 2
    t.decimal "expected_loss", precision: 14, scale: 2
    t.decimal "current_pnl", precision: 14, scale: 2, default: "0.0"
    t.decimal "max_profit", precision: 14, scale: 2, default: "0.0"
    t.decimal "max_loss", precision: 14, scale: 2, default: "0.0"
    t.string "status", default: "active"
    t.decimal "confidence", precision: 3, scale: 2, default: "0.5"
    t.string "exit_reason"
    t.decimal "exit_price", precision: 12, scale: 2
    t.datetime "exit_time"
    t.string "order_id"
    t.string "client_ref"
    t.string "dhan_order_id"
    t.datetime "entry_time", null: false
    t.datetime "last_update_time"
    t.integer "duration_minutes", default: 0
    t.boolean "stop_loss_hit", default: false
    t.boolean "take_profit_hit", default: false
    t.boolean "time_exit_triggered", default: false
    t.boolean "risk_exit_triggered", default: false
    t.decimal "trailing_stop_price", precision: 12, scale: 2
    t.decimal "trailing_stop_percentage", precision: 5, scale: 2
    t.boolean "trailing_stop_active", default: false
    t.decimal "portfolio_allocation", precision: 8, scale: 4
    t.decimal "daily_pnl_contribution", precision: 14, scale: 2, default: "0.0"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["client_ref"], name: "index_trading_positions_on_client_ref", unique: true
    t.index ["entry_time"], name: "index_trading_positions_on_entry_time"
    t.index ["instrument_id", "status"], name: "index_trading_positions_on_instrument_id_and_status"
    t.index ["instrument_id"], name: "index_trading_positions_on_instrument_id"
    t.index ["status", "entry_time"], name: "index_trading_positions_on_status_and_entry_time"
    t.index ["strategy", "status"], name: "index_trading_positions_on_strategy_and_status"
  end

  add_foreign_key "derivatives", "instruments"
  add_foreign_key "trading_positions", "instruments"
end
