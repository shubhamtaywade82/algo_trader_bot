# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TradingPosition, type: :model do
  let(:position) { build(:trading_position) }

  describe 'validations' do
    it { should validate_presence_of(:symbol) }
    it { should validate_presence_of(:quantity) }
    it { should validate_presence_of(:entry_price) }
    it { should validate_presence_of(:position_type) }
    it { should validate_presence_of(:strategy) }
    it { should validate_presence_of(:status) }

    it { should validate_numericality_of(:quantity).is_greater_than(0) }
    it { should validate_numericality_of(:entry_price).is_greater_than(0) }
    it { should validate_inclusion_of(:position_type).in_array(%w[LONG SHORT]) }
    it { should validate_inclusion_of(:status).in_array(%w[OPEN CLOSED]) }
  end

  describe 'associations' do
    # Add any associations if they exist
  end

  describe 'scopes' do
    let!(:open_position) { create(:trading_position, status: 'OPEN') }
    let!(:closed_position) { create(:trading_position, status: 'CLOSED') }

    describe '.open' do
      it 'returns only open positions' do
        expect(TradingPosition.open).to include(open_position)
        expect(TradingPosition.open).not_to include(closed_position)
      end
    end

    describe '.closed' do
      it 'returns only closed positions' do
        expect(TradingPosition.closed).to include(closed_position)
        expect(TradingPosition.closed).not_to include(open_position)
      end
    end
  end

  describe 'methods' do
    describe '#update_pnl' do
      it 'updates unrealized P&L' do
        position.current_price = 160.0
        position.update_pnl
        expect(position.unrealized_pnl).to eq(1000.0) # (160-150) * 100
      end
    end

    describe '#total_pnl' do
      it 'calculates total P&L' do
        position.realized_pnl = 500.0
        position.unrealized_pnl = 300.0
        expect(position.total_pnl).to eq(800.0)
      end
    end

    describe '#profit_percentage' do
      it 'calculates profit percentage' do
        position.current_price = 165.0
        position.entry_price = 150.0
        expect(position.profit_percentage).to eq(10.0) # (165-150)/150 * 100
      end
    end
  end
end
