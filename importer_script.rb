# STEP 0 – prerequisites
require 'csv'
require 'open-uri'

CSV_URL         = 'https://images.dhan.co/api-data/api-scrip-master-detailed.csv'
VALID_EXCHANGES = %w[NSE BSE]
now             = Time.zone.now

# Helper: convert single-letter segment char → enum value
SEGMENT_MAP = { 'I' => 'index', 'E' => 'equity', 'C' => 'currency',
                'D' => 'derivatives', 'M' => 'commodity' }

def safe_date(str)
  Date.parse(str)
rescue StandardError
  nil
end

# STEP 1 – download the master CSV
csv_text = URI.open(CSV_URL).read
puts "📥  downloaded  #{csv_text.bytesize / 1024} KB"

# STEP 2 – parse CSV & keep only NSE / BSE rows
rows = CSV.parse(csv_text, headers: true)
rows = rows.select { |r| VALID_EXCHANGES.include?(r['EXCH_ID']) }
puts "rows after filter: #{rows.size}"

# STEP 3 – split into instruments_rows vs derivatives_rows
instruments_rows  = []
derivatives_rows  = []

rows.each do |row|
  attrs = {
    security_id: row['SECURITY_ID'],
    exchange: row['EXCH_ID'],
    segment: row['SEGMENT'],
    isin: row['ISIN'],
    instrument_code: row['INSTRUMENT'],
    underlying_security_id: row['UNDERLYING_SECURITY_ID'],
    underlying_symbol: row['UNDERLYING_SYMBOL'],
    symbol_name: row['SYMBOL_NAME'],
    display_name: row['DISPLAY_NAME'],
    instrument_type: row['INSTRUMENT_TYPE'],
    series: row['SERIES'],
    lot_size: row['LOT_SIZE']&.to_i,
    expiry_date: safe_date(row['SM_EXPIRY_DATE']),
    strike_price: row['STRIKE_PRICE']&.to_f,
    option_type: row['OPTION_TYPE'],
    tick_size: row['TICK_SIZE']&.to_f,
    expiry_flag: row['EXPIRY_FLAG'],
    bracket_flag: row['BRACKET_FLAG'],
    cover_flag: row['COVER_FLAG'],
    asm_gsm_flag: row['ASM_GSM_FLAG'],
    asm_gsm_category: row['ASM_GSM_CATEGORY'],
    buy_sell_indicator: row['BUY_SELL_INDICATOR'],
    buy_co_min_margin_per: row['BUY_CO_MIN_MARGIN_PER']&.to_f,
    sell_co_min_margin_per: row['SELL_CO_MIN_MARGIN_PER']&.to_f,
    buy_co_sl_range_max_perc: row['BUY_CO_SL_RANGE_MAX_PERC']&.to_f,
    sell_co_sl_range_max_perc: row['SELL_CO_SL_RANGE_MAX_PERC']&.to_f,
    buy_co_sl_range_min_perc: row['BUY_CO_SL_RANGE_MIN_PERC']&.to_f,
    sell_co_sl_range_min_perc: row['SELL_CO_SL_RANGE_MIN_PERC']&.to_f,
    buy_bo_min_margin_per: row['BUY_BO_MIN_MARGIN_PER']&.to_f,
    sell_bo_min_margin_per: row['SELL_BO_MIN_MARGIN_PER']&.to_f,
    buy_bo_sl_range_max_perc: row['BUY_BO_SL_RANGE_MAX_PERC']&.to_f,
    sell_bo_sl_range_max_perc: row['SELL_BO_SL_RANGE_MAX_PERC']&.to_f,
    buy_bo_sl_range_min_perc: row['BUY_BO_SL_RANGE_MIN_PERC']&.to_f,
    sell_bo_sl_min_range: row['SELL_BO_SL_MIN_RANGE']&.to_f,
    buy_bo_profit_range_max_perc: row['BUY_BO_PROFIT_RANGE_MAX_PERC']&.to_f,
    sell_bo_profit_range_max_perc: row['SELL_BO_PROFIT_RANGE_MAX_PERC']&.to_f,
    buy_bo_profit_range_min_perc: row['BUY_BO_PROFIT_RANGE_MIN_PERC']&.to_f,
    sell_bo_profit_range_min_perc: row['SELL_BO_PROFIT_RANGE_MIN_PERC']&.to_f,
    mtf_leverage: row['MTF_LEVERAGE']&.to_f,
    created_at: now,
    updated_at: now
  }

  row['SEGMENT'] == 'D' ? derivatives_rows << attrs : instruments_rows << attrs
end

puts "instrument rows : #{instruments_rows.size}"
puts "derivative rows : #{derivatives_rows.size}"

# STEP 4 – de-dup & bulk-upsert instruments
instruments_rows.uniq! { |h| h.values_at(:security_id, :symbol_name, :exchange, :segment) }

inst_res = Instrument.import(
  instruments_rows,
  batch_size: 1_000,
  on_duplicate_key_update: {
    conflict_target: %i[security_id symbol_name exchange segment],
    columns: %i[
      display_name isin instrument_code instrument_type
      underlying_symbol lot_size tick_size updated_at
    ]
  }
)
puts "✅ upserted instruments: #{inst_res.ids.size}"

# STEP 5 – build lookup {csv_code, UNDERLYING_SYMBOL, exch/seg} ➜ instrument_id
enum_to_csv = Instrument.instrument_codes # "equity"=>"EQUITY", etc.

lookup = Instrument.pluck(
  :id, :instrument_code, :underlying_symbol, :exchange, :segment
).each_with_object({}) do |(id, enum_code, sym, exch, seg), h|
  next if sym.blank?

  csv_code = enum_to_csv[enum_code] || enum_code # keep CSV code itself
  key      = [csv_code, sym.upcase]
  h[key]   = id
end
puts "lookup size: #{lookup.size}"

# STEP 6 – attach instrument_id; split rows
with_parent    = []
without_parent = []

derivatives_rows.each do |h|
  next without_parent << h if h[:underlying_symbol].blank?

  parent_code = InstrumentTypeMapping.underlying_for(h[:instrument_code]) # FUTIDX→INDEX
  key         = [parent_code, h[:underlying_symbol].upcase]

  pp key
  if (pid = lookup[key])
    h[:instrument_id] = pid
    with_parent << h
  else
    without_parent << h
  end
end

puts "derivatives with parent : #{with_parent.size}"
puts "derivatives w/o parent  : #{without_parent.size}"

# STEP 7 – bulk-upsert derivatives (only those with parent)
deriv_res = Derivative.import(
  with_parent,
  batch_size: 1_000,
  on_duplicate_key_update: {
    conflict_target: %i[security_id symbol_name exchange segment],
    columns: %i[
      symbol_name display_name isin instrument_code instrument_type
      underlying_symbol series lot_size tick_size updated_at
    ]
  }
)
puts "✅ upserted derivatives: #{deriv_res.ids.size}"

# STEP 8 – sanity check
puts "total instruments : #{Instrument.count}"
puts "total derivatives : #{Derivative.count}"
Derivative.limit(3).pluck(:symbol_name, :instrument_type, :instrument_id)
