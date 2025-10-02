require 'rails_helper'

RSpec.describe InstrumentsImporter do
  include ActiveSupport::Testing::TimeHelpers

  let(:csv_header) do
    %w[
      SECURITY_ID EXCH_ID SEGMENT ISIN INSTRUMENT UNDERLYING_SECURITY_ID
      UNDERLYING_SYMBOL SYMBOL_NAME DISPLAY_NAME INSTRUMENT_TYPE SERIES
      LOT_SIZE SM_EXPIRY_DATE STRIKE_PRICE OPTION_TYPE TICK_SIZE EXPIRY_FLAG
      BRACKET_FLAG COVER_FLAG ASM_GSM_FLAG ASM_GSM_CATEGORY BUY_SELL_INDICATOR
      BUY_CO_MIN_MARGIN_PER SELL_CO_MIN_MARGIN_PER BUY_CO_SL_RANGE_MAX_PERC
      SELL_CO_SL_RANGE_MAX_PERC BUY_CO_SL_RANGE_MIN_PERC
      SELL_CO_SL_RANGE_MIN_PERC BUY_BO_MIN_MARGIN_PER SELL_BO_MIN_MARGIN_PER
      BUY_BO_SL_RANGE_MAX_PERC SELL_BO_SL_RANGE_MAX_PERC BUY_BO_SL_RANGE_MIN_PERC
      SELL_BO_SL_MIN_RANGE BUY_BO_PROFIT_RANGE_MAX_PERC SELL_BO_PROFIT_RANGE_MAX_PERC
      BUY_BO_PROFIT_RANGE_MIN_PERC SELL_BO_PROFIT_RANGE_MIN_PERC MTF_LEVERAGE
    ].join(',')
  end

  let(:instrument_row) do
    [
      '26000', 'NSE', 'I', 'INE123456789', 'INDEX', '26000', 'NIFTY',
      'NIFTY', 'NIFTY', 'INDEX', '', '0', '', '', '', '0.05', '', '',
      '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '',
      '', '', ''
    ].join(',')
  end

  let(:derivative_row) do
    [
      '26001', 'NSE', 'D', 'INE987654321', 'FUTIDX', '26000', 'NIFTY',
      'NIFTY MAR FUT', 'NIFTY MAR FUT', 'FUTIDX', '', '25', '2025-03-27',
      '', '', '0.05', '', '', '', '', '', '', '', '', '', '', '', '', '', '',
      '', '', '', '', '', '', '', '', '', ''
    ].join(',')
  end

  let(:csv_body) { [csv_header, instrument_row, derivative_row].join("\n") }

  before do
    Rails.cache.clear
    Instrument.delete_all
    Derivative.delete_all
    Setting.delete_all
    allow(described_class).to receive(:fetch_csv_with_cache).and_return(csv_body)
  end

  it 'imports data and records status metadata' do
    travel_to(Time.zone.parse('2024-01-01 10:00:00 UTC')) do
      result = described_class.import_from_url

      expect(result[:instrument_total]).to eq(1)
      expect(result[:derivative_total]).to eq(1)
      expect(result[:instrument_upserts]).to eq(1)
      expect(result[:derivative_upserts]).to eq(1)

      expect(Instrument.count).to eq(1)
      expect(Derivative.count).to eq(1)

      expect(Setting.fetch('instruments.instrument_total')).to eq('1')
      expect(Setting.fetch('instruments.derivative_total')).to eq('1')
      expect(Setting.fetch('instruments.last_instrument_rows')).to eq('1')
      expect(Setting.fetch('instruments.last_derivative_rows')).to eq('1')
      expect(Setting.fetch('instruments.last_instrument_upserts')).to eq('1')
      expect(Setting.fetch('instruments.last_derivative_upserts')).to eq('1')

      recorded_at = Time.zone.parse(Setting.fetch('instruments.last_imported_at'))
      expect(recorded_at).to eq(Time.zone.now)

      duration = Setting.fetch('instruments.last_import_duration_sec').to_f
      expect(duration).to be >= 0.0
    end
  end
end
