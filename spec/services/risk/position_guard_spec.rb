# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Risk::PositionGuard, type: :service do
  let(:guard) { described_class.new }
  let(:position) { create(:trading_position) }
  let(:signal) { create_test_signals.first }

  describe '#validate_position' do
    it 'validates position meets risk criteria' do
      result = guard.validate_position(position)
      expect(result[:valid]).to be true
    end

    it 'rejects positions exceeding risk limits' do
      position.update!(quantity: 10000) # Very large position
      result = guard.validate_position(position)
      expect(result[:valid]).to be false
    end
  end

  describe '#calculate_position_risk' do
    it 'calculates position risk metrics' do
      risk = guard.calculate_position_risk(position)
      expect(risk).to include(:var, :max_loss, :risk_score)
    end
  end

  describe '#check_concentration_risk' do
    it 'checks for concentration risk' do
      result = guard.check_concentration_risk(position)
      expect(result[:concentrated]).to be_in([true, false])
    end
  end

  describe '#validate_signal_risk' do
    it 'validates signal risk before execution' do
      result = guard.validate_signal_risk(signal)
      expect(result[:valid]).to be true
    end
  end
end
