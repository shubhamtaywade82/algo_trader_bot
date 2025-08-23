require 'rails_helper'
RSpec.describe PriceMath do
  it 'rounds/floors/ceils to 0.05' do
    expect(described_class.round_tick(101.025)).to eq(101.05)
    expect(described_class.floor_tick(101.049)).to eq(101.00)
    expect(described_class.ceil_tick(101.001)).to eq(101.05)
  end

  it 'validates tick size' do
    expect(described_class.valid_tick?(101.05)).to be true
    expect(described_class.valid_tick?(101.07)).to be false
  end
end