# spec/services/orders/executor_spec.rb
require 'rails_helper'
RSpec.describe Orders::Executor do
  it 'is idempotent by client_ref' do
    ins = create(:instrument) # your factory
    allow(DhanHQ::SuperOrders).to receive(:place).and_return({ super_order_id: 'X1', avg_price: 100.0 })
    params = Risk::ToSuperParams.call(entry_premium: 100)
    ref = "cf:#{SecureRandom.hex(2)}"

    a = described_class.call(instrument: ins, side: :buy, qty: 75, entry_type: :market, risk_params: params, client_ref: ref)
    b = described_class.call(instrument: ins, side: :buy, qty: 75, entry_type: :market, risk_params: params, client_ref: ref)

    expect(a.id).to eq(b.id)
    expect(DhanHQ::SuperOrders).to have_received(:place).once
  end
end
