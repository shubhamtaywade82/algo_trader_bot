# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Signal::Generator, type: :service do
  let(:generator) { described_class.new }
  let(:market_data) { { symbol: 'NIFTY', price: 25000.0, volume: 1000000 } }

  describe '#generate_signals' do
    before do
      allow(generator).to receive(:fetch_market_data).and_return([market_data])
      allow(generator).to receive(:run_strategies)
    end

    it 'generates signals for market data' do
      expect(generator).to receive(:fetch_market_data)
      expect(generator).to receive(:run_strategies).with([market_data])
      generator.generate_signals
    end
  end

  describe '#fetch_market_data' do
    before do
      allow(Market::SpotFetcher).to receive(:call).and_return(25000.0)
      allow(Market::VolumeFetcher).to receive(:call).and_return(1000000)
    end

    it 'fetches market data for symbols' do
      data = generator.send(:fetch_market_data)
      expect(data).to be_an(Array)
      expect(data.first).to include(:symbol, :price, :volume)
    end
  end

  describe '#run_strategies' do
    let(:strategies) { [Strategy::OptionsScalper.new, Strategy::TrendFollower.new] }
    
    before do
      allow(Strategy::Base).to receive(:subclasses).and_return(strategies)
      allow(generator).to receive(:execute_strategy)
    end

    it 'runs all strategies on market data' do
      expect(generator).to receive(:execute_strategy).twice
      generator.send(:run_strategies, [market_data])
    end
  end

  describe '#execute_strategy' do
    let(:strategy) { Strategy::OptionsScalper.new }
    let(:signals) { [create_test_signals.first] }

    before do
      allow(strategy).to receive(:generate_signals).and_return(signals)
      allow(generator).to receive(:validate_signal)
    end

    it 'executes strategy and validates signals' do
      expect(strategy).to receive(:generate_signals).with([market_data])
      expect(generator).to receive(:validate_signal).with(signals.first)
      generator.send(:execute_strategy, strategy, [market_data])
    end
  end

  describe '#validate_signal' do
    let(:signal) { create_test_signals.first }

    it 'validates signal meets criteria' do
      result = generator.send(:validate_signal, signal)
      expect(result[:valid]).to be true
    end

    it 'rejects invalid signals' do
      signal.action = nil
      result = generator.send(:validate_signal, signal)
      expect(result[:valid]).to be false
    end
  end
end
