require 'rails_helper'
require Rails.root.join('app/models/candle')
require Rails.root.join('app/models/candle_series')
require Rails.root.join('app/scalpers/base/engine')
require Rails.root.join('app/scalpers/base/risk_profile')
require Rails.root.join('app/scalpers/base/sizing')
require Rails.root.join('app/scalpers/base/runner')
require Rails.root.join('app/scalpers/options/runner')
require Rails.root.join('app/scalpers/options/policy')
require Rails.root.join('app/scalpers/options/sizer')
require Rails.root.join('app/scalpers/options/executor')
require Rails.root.join('app/scalpers/options/chain_picker')

RSpec.describe Scalpers::Options::Runner do
  let(:logger) { Logger.new(nil) }
  let(:now) { Time.zone.parse('2024-05-15 10:05:00') }
  let(:underlying) do
    double(
      :instrument,
      exchange_segment: 'IDX_I',
      security_id: '13',
      symbol_name: 'NIFTY',
      display_name: 'Nifty 50',
      lot_size: 50
    )
  end
  let(:watch_entry) do
    {
      instrument: underlying,
      cash_balance: 600_000,
      min_oi: 5000,
      max_spread_pct: 1.5,
      stop_loss_pct: 30,
      target_pct: 60,
      trailing_sl_points: 5,
      trailing_jump: 2,
      analyzer: { strategy_type: 'intraday' }
    }
  end

  let(:series_1m) { CandleSeries.new(symbol: 'NIFTY50', interval: '1') }
  let(:series_5m) { CandleSeries.new(symbol: 'NIFTY50', interval: '5') }

  before do
    [series_1m, series_5m].each do |series|
      series.add_candle(Candle.new(ts: now - 2.minutes, open: 18_000, high: 18_020, low: 17_980, close: 18_010, volume: 120_000))
      series.add_candle(Candle.new(ts: now - 1.minute, open: 18_010, high: 18_030, low: 17_990, close: 18_025, volume: 140_000))
      series.add_candle(Candle.new(ts: now, open: 18_025, high: 18_050, low: 18_000, close: 18_040, volume: 150_000))
    end
  end

  let(:bars_cache) { instance_double(Stores::BarsCache) }
  let(:ltp_cache) { instance_double(Stores::LtpCache) }
  let(:risk_profile) { instance_double(Scalpers::Base::RiskProfile) }
  let(:engine) { instance_double(Scalpers::Base::Engine) }
  let(:base_sizing) { Scalpers::Base::Sizing.new(option_premium_cap_pct: 1.0, min_quantity: 1) }
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

  let(:derivative) do
    double(
      :derivative,
      symbol_name: 'NIFTY24MAY18000CE',
      display_name: 'NIFTY 24 MAY 18000 CE',
      lot_size: 50,
      exchange_segment: 'NSE_FNO',
      security_id: '18000'
    )
  end

  let(:leg) do
    {
      derivative: derivative,
      ltp: 120.0,
      symbol: 'NIFTY24MAY18000CE',
      oi: 7000,
      spread_pct: 1.0
    }
  end

  let(:chain_picker) { instance_double(Scalpers::Options::ChainPicker) }
  let(:policy) { Scalpers::Options::Policy.new(chain_picker: chain_picker, logger: logger) }
  let(:sizer) { Scalpers::Options::Sizer.new(base_sizing: base_sizing, logger: logger) }
  let(:executor) { instance_double(Scalpers::Options::Executor) }
  let(:runner) do
    described_class.new(
      infra: infra,
      watchlist: [watch_entry],
      policy: policy,
      sizer: sizer,
      executor: executor,
      logger: logger,
      poll_interval: 5,
      idempotency_ttl: 90
    )
  end

  let(:signal) do
    Scalpers::Base::Engine::Signal.new(
      symbol: 'NIFTY50',
      direction: :long,
      confidence: 0.65,
      regime: :normal,
      reason: 'bos_up',
      metadata: { atr: 15.0, confidence: 0.65 }
    )
  end

  before do
    allow(bars_cache).to receive(:series).with(segment: 'IDX_I', security_id: '13', interval: '1').and_return(series_1m)
    allow(bars_cache).to receive(:series).with(segment: 'IDX_I', security_id: '13', interval: '5').and_return(series_5m)
    allow(ltp_cache).to receive(:ltp).with(segment: 'IDX_I', security_id: '13').and_return(18_040.0)
    allow(engine).to receive(:signal_for).and_return(signal)
  end

  it 'sends an options order when a leg qualifies' do
    allow(chain_picker).to receive(:pick).and_return(leg)
    allow(risk_profile).to receive(:allow_entry?).and_return([true, 'ok'])

    captured = nil
    outer_infra = infra

    expect(executor).to receive(:execute) do |decision:, infra:, config:|
      expect(infra).to equal(outer_infra)
      expect(config).to eq(watch_entry)
      captured = decision
      true
    end

    runner.run_once(now: now)

    expect(captured).to have_attributes(kind: :option, direction: :long)
    expect(captured.instrument).to eq(derivative)
    expect(captured.quantity).to eq(50)
    expect(captured.metadata[:lots]).to eq(1)
    expect(captured.stop_loss).to be < captured.entry_price
    expect(captured.take_profit).to be > captured.entry_price
  end

  it 'skips when risk profile blocks the trade' do
    allow(chain_picker).to receive(:pick).and_return(leg)
    allow(risk_profile).to receive(:allow_entry?).and_return([false, 'day_down_reached'])

    expect(executor).not_to receive(:execute)

    runner.run_once(now: now)
  end

  it 'skips when chain picker cannot find a leg' do
    allow(chain_picker).to receive(:pick).and_return(nil)
    allow(risk_profile).to receive(:allow_entry?).and_return([true, 'ok'])

    expect(executor).not_to receive(:execute)

    runner.run_once(now: now)
  end
end
