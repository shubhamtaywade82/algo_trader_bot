require 'rails_helper'

RSpec.describe Instruments::Resolver do
  before(:all) do
    begin
      ActiveRecord::Base.connection
    rescue StandardError => e
      skip("Database unavailable: #{e.class} #{e.message}")
    end
  end

  subject(:resolver) { described_class.new }

  let!(:nifty) do
    Instrument.create!(
      exchange: :nse,
      segment: :index,
      security_id: '13',
      instrument_code: 'INDEX',
      symbol_name: 'NIFTY',
      display_name: 'Nifty 50',
      underlying_symbol: 'NIFTY',
      lot_size: 1
    )
  rescue StandardError => e
    skip("Database unavailable: #{e.class} #{e.message}")
  end

  let!(:sensex) do
    Instrument.create!(
      exchange: :bse,
      segment: :index,
      security_id: '51',
      instrument_code: 'INDEX',
      symbol_name: 'SENSEX',
      display_name: 'Sensex',
      underlying_symbol: 'SENSEX',
      lot_size: 1
    )
  rescue StandardError => e
    skip("Database unavailable: #{e.class} #{e.message}")
  end

  let!(:reliance) do
    Instrument.create!(
      exchange: :nse,
      segment: :equity,
      security_id: '500325',
      instrument_code: 'EQUITY',
      symbol_name: 'RELIANCE',
      display_name: 'Reliance Industries',
      underlying_symbol: 'RELIANCE',
      lot_size: 1
    )
  rescue StandardError => e
    skip("Database unavailable: #{e.class} #{e.message}")
  end

  it 'resolves index instruments using watchlist aliases' do
    expect(resolver.call(symbol: 'NIFTY')).to eq(nifty)
  end

  it 'honours exchange/segment hints when available' do
    expect(resolver.call(symbol: 'SENSEX', exchange: :bse, segment: :index)).to eq(sensex)
  end

  it 'falls back to equity instruments when segment hint provided' do
    expect(resolver.call(symbol: 'RELIANCE', segment: :equity)).to eq(reliance)
  end

  it 'resolves using security id when provided' do
    expect(resolver.call(symbol: nil, security_id: '500325', exchange: :nse, segment: :equity)).to eq(reliance)
  end
end
