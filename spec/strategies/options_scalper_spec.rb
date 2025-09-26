# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Strategy::OptionsScalper, type: :strategy do
  let(:strategy) { described_class.new }
  let(:market_data) { create_test_market_data }

  describe '#initialize' do
    it 'sets default parameters' do
      expect(strategy.name).to eq('OptionsScalper')
      expect(strategy.enabled).to be true
    end
  end

  describe '#generate_signals' do
    before do
      allow(strategy).to receive(:fetch_market_data).and_return(market_data)
    end

    it 'generates trading signals' do
      signals = strategy.generate_signals
      expect(signals).to be_an(Array)
    end

    it 'includes required signal fields' do
      signals = strategy.generate_signals
      if signals.any?
        signal = signals.first
        expect(signal).to include('strategy', 'action', 'confidence', 'instrument')
      end
    end
  end

  describe '#analyze_volatility' do
    it 'analyzes market volatility' do
      volatility = strategy.send(:analyze_volatility, market_data)
      expect(volatility).to be_a(Numeric)
    end
  end

  describe '#calculate_confidence' do
    it 'calculates signal confidence' do
      confidence = strategy.send(:calculate_confidence, market_data)
      expect(confidence).to be_between(0.0, 1.0)
    end
  end

  describe '#should_generate_signal' do
    it 'determines if signal should be generated' do
      result = strategy.send(:should_generate_signal, market_data)
      expect(result).to be_in([true, false])
    end
  end
end
