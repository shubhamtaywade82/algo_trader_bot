# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Trading::Engine, type: :service do
  let(:engine) { described_class.new }
  let(:strategy) { instance_double('Strategy::OptionsScalper') }
  let(:signal) { create_test_signals.first }

  before do
    allow(Strategy::OptionsScalper).to receive(:new).and_return(strategy)
    allow(strategy).to receive(:generate_signals).and_return([signal])
    allow(engine).to receive(:sleep)
  end

  describe '#initialize' do
    it 'sets default values' do
      expect(engine.running).to be false
      expect(engine.strategies).to be_empty
      expect(engine.interval).to eq(5)
    end
  end

  describe '#add_strategy' do
    it 'adds strategy to the list' do
      engine.add_strategy(Strategy::OptionsScalper)
      expect(engine.strategies).to include(Strategy::OptionsScalper)
    end
  end

  describe '#start' do
    before do
      engine.add_strategy(Strategy::OptionsScalper)
    end

    it 'starts the trading loop' do
      expect(engine).to receive(:trading_loop)
      engine.start
    end

    it 'sets running to true' do
      allow(engine).to receive(:trading_loop)
      engine.start
      expect(engine.running).to be true
    end
  end

  describe '#stop' do
    before do
      engine.instance_variable_set(:@running, true)
    end

    it 'stops the trading loop' do
      engine.stop
      expect(engine.running).to be false
    end
  end

  describe '#trading_loop' do
    before do
      engine.add_strategy(Strategy::OptionsScalper)
      allow(engine).to receive(:running?).and_return(true, false)
    end

    it 'generates signals from all strategies' do
      expect(strategy).to receive(:generate_signals)
      engine.send(:trading_loop)
    end

    it 'processes signals' do
      expect(engine).to receive(:process_signals).with([signal])
      engine.send(:trading_loop)
    end
  end

  describe '#process_signals' do
    let(:signals) { [signal] }

    before do
      allow(engine).to receive(:validate_signal).and_return(true)
      allow(engine).to receive(:execute_signal)
    end

    it 'validates each signal' do
      expect(engine).to receive(:validate_signal).with(signal)
      engine.send(:process_signals, signals)
    end

    it 'executes valid signals' do
      expect(engine).to receive(:execute_signal).with(signal)
      engine.send(:process_signals, signals)
    end
  end

  describe '#validate_signal' do
    it 'validates signal structure' do
      expect(engine.send(:validate_signal, signal)).to be true
    end

    it 'rejects invalid signals' do
      invalid_signal = { 'action' => 'INVALID' }
      expect(engine.send(:validate_signal, invalid_signal)).to be false
    end
  end

  describe '#execute_signal' do
    before do
      allow(engine).to receive(:paper_mode?).and_return(true)
      allow(engine).to receive(:log_signal)
    end

    it 'logs signal in paper mode' do
      expect(engine).to receive(:log_signal).with(signal)
      engine.send(:execute_signal, signal)
    end

    it 'executes real order when not in paper mode' do
      allow(engine).to receive(:paper_mode?).and_return(false)
      allow(engine).to receive(:place_order)
      expect(engine).to receive(:place_order).with(signal)
      engine.send(:execute_signal, signal)
    end
  end
end
