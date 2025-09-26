# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Signal::Processor, type: :service do
  let(:processor) { described_class.new }
  let(:signal) { create_test_signals.first }

  describe '#process_signal' do
    before do
      allow(processor).to receive(:validate_signal).and_return({ valid: true })
      allow(processor).to receive(:execute_signal)
    end

    it 'processes valid signals' do
      expect(processor).to receive(:validate_signal).with(signal)
      expect(processor).to receive(:execute_signal).with(signal)
      processor.process_signal(signal)
    end
  end

  describe '#validate_signal' do
    it 'validates signal structure' do
      result = processor.send(:validate_signal, signal)
      expect(result[:valid]).to be true
    end

    it 'rejects signals with missing required fields' do
      signal.action = nil
      result = processor.send(:validate_signal, signal)
      expect(result[:valid]).to be false
    end
  end

  describe '#execute_signal' do
    before do
      allow(processor).to receive(:create_position)
      allow(processor).to receive(:log_execution)
    end

    it 'creates position for buy signals' do
      signal.action = 'BUY'
      expect(processor).to receive(:create_position).with(signal)
      processor.send(:execute_signal, signal)
    end

    it 'logs execution' do
      expect(processor).to receive(:log_execution).with(signal)
      processor.send(:execute_signal, signal)
    end
  end

  describe '#create_position' do
    it 'creates trading position' do
      expect { processor.send(:create_position, signal) }
        .to change(TradingPosition, :count).by(1)
    end
  end

  describe '#log_execution' do
    it 'logs signal execution' do
      expect(Rails.logger).to receive(:info)
      processor.send(:log_execution, signal)
    end
  end
end
