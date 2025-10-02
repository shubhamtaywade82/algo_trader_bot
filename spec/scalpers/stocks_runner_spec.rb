require 'rails_helper'
require Rails.root.join('app/models/candle')
require Rails.root.join('app/models/candle_series')
require Rails.root.join('app/scalpers/base/engine')
require Rails.root.join('app/scalpers/base/risk_profile')
require Rails.root.join('app/scalpers/base/sizing')
require Rails.root.join('app/scalpers/base/runner')
require Rails.root.join('app/scalpers/stocks/runner')
require Rails.root.join('app/scalpers/stocks/policy')
require Rails.root.join('app/scalpers/stocks/sizer')
require Rails.root.join('app/scalpers/stocks/executor')

RSpec.describe Scalpers::Stocks::Runner do
  let(:logger) { Logger.new(nil) }
  let(:now) { Time.zone.parse('2024-05-15 09:45:00') }
  let(:instrument) do
    double(
      :instrument,
      exchange_segment: 'NSE_EQ',
      security_id: '12345',
      symbol_name: 'TCS',
      display_name: 'TCS',
      lot_size: 5
    )
  end
  let(:watch_entry) do
    {
      instrument: instrument,
      cash_balance: 200_000,
      estimated_spread_pct: 0.25,
      max_spread_pct: 0.6,
      stop_loss_pct: 1.0,
      target_pct: 2.0,
      rr_multiple: 2.0,
      atr_multiple: 1.1,
      lot_size: 5
    }
  end

  let(:series_1m) { CandleSeries.new(symbol: 'TCS', interval: '1') }
  let(:series_5m) { CandleSeries.new(symbol: 'TCS', interval: '5') }

  before do
    [series_1m, series_5m].each do |series|
      series.add_candle(Candle.new(ts: now - 2.minutes, open: 100, high: 101, low: 99.5, close: 100.5, volume: 8000))
      series.add_candle(Candle.new(ts: now - 1.minute, open: 100.5, high: 101.5, low: 100, close: 101.2, volume: 9000))
      series.add_candle(Candle.new(ts: now, open: 101.2, high: 103, low: 101, close: 102.8, volume: 11_000))
    end
  end

  let(:bars_cache) { instance_double(Stores::BarsCache) }
  let(:ltp_cache) { instance_double(Stores::LtpCache) }
  let(:risk_profile) { instance_double(Scalpers::Base::RiskProfile) }
  let(:engine) { instance_double(Scalpers::Base::Engine) }
  let(:base_sizing) { Scalpers::Base::Sizing.new(risk_per_trade_pct: 1.0, max_stock_leverage: 2.0, min_quantity: 1) }
  let(:infra) do
    double(
      :infra,
      trading_enabled?: true,
      bars_cache: bars_cache,
      ltp_cache: ltp_cache,
      risk_profile: risk_profile,
      engine: engine,
      sizing: base_sizing
    )
  end

  let(:policy) { Scalpers::Stocks::Policy.new(logger: logger) }
  let(:sizer) { Scalpers::Stocks::Sizer.new(base_sizing: base_sizing, logger: logger) }
  let(:executor) { instance_double(Scalpers::Stocks::Executor) }
  let(:runner) do
    described_class.new(
      infra: infra,
      watchlist: [watch_entry],
      policy: policy,
      sizer: sizer,
      executor: executor,
      logger: logger,
      poll_interval: 5,
      idempotency_ttl: 120
    )
  end

  let(:signal) do
    Scalpers::Base::Engine::Signal.new(
      symbol: 'TCS',
      direction: :long,
      confidence: 0.7,
      regime: :normal,
      reason: 'bos_up',
      metadata: { atr: 1.4, confidence: 0.7 }
    )
  end

  before do
    allow(bars_cache).to receive(:series).with(segment: 'NSE_EQ', security_id: '12345', interval: '1').and_return(series_1m)
    allow(bars_cache).to receive(:series).with(segment: 'NSE_EQ', security_id: '12345', interval: '5').and_return(series_5m)
    allow(ltp_cache).to receive(:ltp).with(segment: 'NSE_EQ', security_id: '12345').and_return(102.8)
    allow(engine).to receive(:signal_for).and_return(signal)
    allow(risk_profile).to receive(:allow_entry?).and_return([true, 'ok'])
  end

  it 'dispatches a stock order when all gates allow entry' do
    captured = nil
    outer_infra = infra

    expect(executor).to receive(:execute) do |decision:, infra:, config:|
      expect(infra).to equal(outer_infra)
      expect(config).to eq(watch_entry)
      captured = decision
      true
    end

    runner.run_once(now: now)

    expect(captured).to have_attributes(symbol: 'TCS', kind: :stock, direction: :long)
    expect(captured.quantity).to be > 0
    expect(captured.stop_loss).to be < captured.entry_price
    expect(captured.take_profit).to be > captured.entry_price
    expect(captured.metadata[:notional]).to be > 0
    expect(captured.expected_loss).to be > 0
  end

  it 'does not re-issue the same decision within the idempotency window' do
    expect(executor).to receive(:execute).once.and_return(true)

    runner.run_once(now: now)
    runner.run_once(now: now + 30.seconds)
  end
end
