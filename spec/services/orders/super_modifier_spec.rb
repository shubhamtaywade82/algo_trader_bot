# spec/services/orders/super_modifier_spec.rb
require 'rails_helper'
RSpec.describe Orders::SuperModifier do
  it 'tightens only (reduce TP, raise trail, increase SL if absolute level semantics)' do
    ord = create(:order, super_ref: 'X1', sl_value: 20.0, tp_value: 60.0, trail_sl_value: 15.0)
    allow(DhanHQ::SuperOrders).to receive(:modify).and_return({ ok: true })

    described_class.call(order: ord, new_tp_value: 55.0, new_trail_sl_value: 18.0, new_sl_value: 22.0)

    ord.reload
    expect(ord.tp_value).to eq(55.0)
    expect(ord.trail_sl_value).to eq(18.0)
    expect(ord.sl_value).to eq(22.0)
  end
end
