# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Position::Monitor, type: :service do
  let(:monitor) { described_class.new }
  let(:position) { create(:trading_position) }

  describe '#monitor_positions' do
    before do
      allow(TradingPosition).to receive(:open).and_return([position])
      allow(monitor).to receive(:update_position_pnl)
      allow(monitor).to receive(:check_exit_conditions)
    end

    it 'monitors all open positions' do
      expect(TradingPosition).to receive(:open)
      monitor.monitor_positions
    end

    it 'updates position P&L' do
      expect(monitor).to receive(:update_position_pnl).with(position)
      monitor.monitor_positions
    end

    it 'checks exit conditions' do
      expect(monitor).to receive(:check_exit_conditions).with(position)
      monitor.monitor_positions
    end
  end

  describe '#update_position_pnl' do
    before do
      allow(monitor).to receive(:fetch_current_price).and_return(160.0)
    end

    it 'updates unrealized P&L' do
      monitor.send(:update_position_pnl, position)
      expect(position.unrealized_pnl).to be > 0
    end
  end

  describe '#check_exit_conditions' do
    context 'when stop loss is hit' do
      before do
        position.update!(current_price: 130.0, stop_loss: 140.0)
        allow(monitor).to receive(:exit_position)
      end

      it 'triggers exit' do
        expect(monitor).to receive(:exit_position).with(position, 'stop_loss')
        monitor.send(:check_exit_conditions, position)
      end
    end

    context 'when take profit is hit' do
      before do
        position.update!(current_price: 180.0, take_profit: 170.0)
        allow(monitor).to receive(:exit_position)
      end

      it 'triggers exit' do
        expect(monitor).to receive(:exit_position).with(position, 'take_profit')
        monitor.send(:check_exit_conditions, position)
      end
    end
  end
end
