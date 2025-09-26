# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Notifications::TelegramNotifier, type: :service do
  let(:notifier) { described_class.new }
  let(:message) { 'Test notification message' }

  describe '#initialize' do
    it 'sets up Telegram configuration' do
      expect(notifier.bot_token).to be_present
      expect(notifier.chat_id).to be_present
    end
  end

  describe '#send_message' do
    before do
      allow(notifier).to receive(:make_request).and_return({ 'ok' => true })
    end

    it 'sends message successfully' do
      result = notifier.send_message(message)
      expect(result[:success]).to be true
    end

    it 'handles API errors' do
      allow(notifier).to receive(:make_request).and_return({ 'ok' => false, 'error_code' => 400 })
      result = notifier.send_message(message)
      expect(result[:success]).to be false
    end
  end

  describe '#send_trade_alert' do
    let(:trade_data) do
      {
        action: 'BUY',
        symbol: 'NIFTY24000CE',
        quantity: 100,
        price: 150.0
      }
    end

    it 'formats and sends trade alert' do
      allow(notifier).to receive(:send_message).and_return({ success: true })
      result = notifier.send_trade_alert(trade_data)
      expect(result[:success]).to be true
    end
  end

  describe '#send_error_alert' do
    let(:error) { StandardError.new('Test error') }

    it 'sends error notification' do
      allow(notifier).to receive(:send_message).and_return({ success: true })
      result = notifier.send_error_alert(error)
      expect(result[:success]).to be true
    end
  end
end
