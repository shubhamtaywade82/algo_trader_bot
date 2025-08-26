require 'rails_helper'

RSpec.describe Risk::Guard do
  let(:guard) { described_class.new }

  before do
    Setting.put('trading_enabled', 'true')
    Setting.put('risk.per_trade_rupees', '750')
    Setting.put('risk.daily_loss_cap_rupees', '1500')
    Setting.put('risk.max_trades_per_day', '2')

    # Stub Live::TickCache
    stub_const('Live::TickCache', Module.new)
    allow(Live::TickCache).to receive(:get).and_return({ ltp: 100.0, ts: Time.now })
  end

  it 'blocks when trading disabled' do
    Setting.put('trading_enabled', 'false')
    ok, reason = guard.allow_entry?(expected_risk_rupees: 500, seg: 'NSE_FNO', sid: 123)
    expect(ok).to be false
    expect(reason).to eq('trading_disabled')
  end

  it 'blocks on stale ticks' do
    allow(Live::TickCache).to receive(:get).and_return({ ltp: 100.0, ts: Time.now - 10 })
    ok, reason = guard.allow_entry?(expected_risk_rupees: 500, seg: 'NSE_FNO', sid: 123)
    expect(ok).to be false
    expect(reason).to eq('ticks_stale')
  end

  it 'blocks when daily loss cap would be breached' do
    # Simulate realized loss today exceeding (cap - expected_risk)
    allow_any_instance_of(Risk::Guard).to receive(:realized_loss_today_abs).and_return(1200.0)
    ok, reason = guard.allow_entry?(expected_risk_rupees: 400, seg: 'NSE_FNO', sid: 123)
    expect(ok).to be false
    expect(reason).to eq('daily_loss_cap')
  end

  it 'blocks when max trades reached' do
    create_list(:order, 2, created_at: Time.zone.now) # adjust to your factories
    ok, reason = guard.allow_entry?(expected_risk_rupees: 200, seg: 'NSE_FNO', sid: 123)
    expect(ok).to be false
    expect(reason).to eq('max_trades_reached')
  end

  it 'allows when all gates pass' do
    allow_any_instance_of(Risk::Guard).to receive(:realized_loss_today_abs).and_return(200.0)
    ok, reason = guard.allow_entry?(expected_risk_rupees: 200, seg: 'NSE_FNO', sid: 123)
    expect(ok).to be true
    expect(reason).to eq('ok')
  end
end
