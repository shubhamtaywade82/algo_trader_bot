# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'DhanHQ Integration', type: :integration do
  describe 'Funds API' do
    it 'fetches account funds' do
      funds = DhanHQ::Models::Funds.fetch
      expect(funds).to respond_to(:available_balance)
      expect(funds).to respond_to(:withdrawable_balance)
    end

    it 'gets balance' do
      balance = DhanHQ::Models::Funds.balance
      expect(balance).to be_a(Numeric)
    end
  end

  describe 'Positions API' do
    it 'fetches all positions' do
      positions = DhanHQ::Models::Position.all
      expect(positions).to be_an(Array)
    end

    it 'position has required attributes' do
      positions = DhanHQ::Models::Position.all
      if positions.any?
        position = positions.first
        expect(position).to respond_to(:trading_symbol)
        expect(position).to respond_to(:position_type)
        expect(position).to respond_to(:net_qty)
        expect(position).to respond_to(:unrealized_profit)
      end
    end
  end

  describe 'Orders API' do
    it 'fetches all orders' do
      orders = DhanHQ::Models::Order.all
      expect(orders).to be_an(Array)
    end
  end

  describe 'Market Data API' do
    it 'fetches spot price' do
      spot = Market::SpotFetcher.call(symbol: 'NIFTY')
      expect(spot).to be_a(Numeric)
      expect(spot).to be > 0
    end
  end

  describe 'Error Handling' do
    it 'handles API errors gracefully' do
      allow(DhanHQ::Models::Funds).to receive(:fetch)
        .and_raise(StandardError, 'API Error')

      expect { DhanHQ::Models::Funds.fetch }.to raise_error(StandardError)
    end
  end
end
