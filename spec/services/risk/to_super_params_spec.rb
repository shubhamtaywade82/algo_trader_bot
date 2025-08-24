# spec/services/risk/to_super_params_spec.rb
require 'rails_helper'
RSpec.describe Risk::ToSuperParams do
  it 'rounds to 0.05 and guards non-negative' do
    rp = described_class.call(entry_premium: 123.42)
    %i[sl_value tp_value trail_sl_value trail_sl_jump].each do |k|
      expect(PriceMath.valid_tick?(rp[k])).to be true
      expect(rp[k]).to be >= 0.05
    end
  end
end
