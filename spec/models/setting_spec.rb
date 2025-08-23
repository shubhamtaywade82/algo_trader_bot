require 'rails_helper'

RSpec.describe Setting, type: :model do
  it 'puts and fetches with cache invalidation' do
    Setting.put('trading_enabled', 'true')
    expect(Setting.fetch_bool('trading_enabled')).to eq(true)
    Setting.put('trading_enabled', 'false')
    expect(Setting.fetch_bool('trading_enabled')).to eq(false)
  end
end