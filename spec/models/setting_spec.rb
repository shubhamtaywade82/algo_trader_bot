require 'rails_helper'

RSpec.describe Setting do
  it 'puts and fetches with cache invalidation' do
    described_class.put('trading_enabled', 'true')
    expect(described_class.fetch_bool('trading_enabled')).to be(true)
    described_class.put('trading_enabled', 'false')
    expect(described_class.fetch_bool('trading_enabled')).to be(false)
  end
end