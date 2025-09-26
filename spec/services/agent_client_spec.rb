# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AgentClient, type: :service do
  let(:client) { described_class.new }
  let(:agent_url) { 'http://localhost:3001' }

  before do
    allow(ENV).to receive(:[]).with('AGENT_URL').and_return(agent_url)
  end

  describe '#initialize' do
    it 'sets up agent URL' do
      expect(client.instance_variable_get(:@agent_url)).to eq(agent_url)
    end
  end

  describe '#send_signal' do
    let(:signal) { create_test_signals.first }

    before do
      allow(client).to receive(:make_request).and_return({ success: true })
    end

    it 'sends signal to agent' do
      expect(client).to receive(:make_request)
        .with(:post, '/signals', signal.to_h)
      client.send_signal(signal)
    end
  end

  describe '#get_recommendation' do
    let(:market_data) { { symbol: 'NIFTY', price: 25000.0 } }

    before do
      allow(client).to receive(:make_request)
        .and_return({ recommendation: 'BUY', confidence: 0.8 })
    end

    it 'gets recommendation from agent' do
      result = client.get_recommendation(market_data)
      expect(result[:recommendation]).to eq('BUY')
      expect(result[:confidence]).to eq(0.8)
    end
  end

  describe '#ping' do
    before do
      allow(client).to receive(:make_request)
        .and_return({ status: 'ok', timestamp: Time.current.to_i })
    end

    it 'pings agent for health check' do
      result = client.ping
      expect(result[:status]).to eq('ok')
    end
  end

  describe '#make_request' do
    let(:response) { double('Response', success?: true, body: '{"result": "success"}') }

    before do
      allow(Faraday).to receive(:new).and_return(double('Connection'))
      allow_any_instance_of(Faraday::Connection).to receive(:post)
        .and_return(response)
    end

    it 'makes HTTP request to agent' do
      result = client.send(:make_request, :post, '/test', {})
      expect(result).to eq({ 'result' => 'success' })
    end
  end
end
