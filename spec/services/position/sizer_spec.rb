# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Position::Sizer, type: :service do
  let(:sizer) { described_class.new }
  let(:signal) { create_test_signals.first }
  let(:portfolio_state) { create_test_portfolio_state }

  describe '#calculate_position_size' do
    it 'calculates position size based on risk' do
      size = sizer.calculate_position_size(signal, portfolio_state)
      expect(size).to be > 0
      expect(size).to be <= portfolio_state['available_cash']
    end

    it 'respects maximum position size limit' do
      allow(sizer).to receive(:max_position_size).and_return(1000)
      size = sizer.calculate_position_size(signal, portfolio_state)
      expect(size).to be <= 1000
    end
  end

  describe '#calculate_risk_amount' do
    it 'calculates risk amount based on stop loss' do
      signal['stop_loss'] = 140.0
      signal['price'] = 150.0
      risk_amount = sizer.calculate_risk_amount(signal)
      expect(risk_amount).to eq(10.0)
    end
  end

  describe '#validate_position_size' do
    it 'validates position size is within limits' do
      size = 1000
      expect(sizer.validate_position_size(size, portfolio_state)).to be true
    end

    it 'rejects position size exceeding available cash' do
      size = portfolio_state['available_cash'] + 1000
      expect(sizer.validate_position_size(size, portfolio_state)).to be false
    end
  end
end
