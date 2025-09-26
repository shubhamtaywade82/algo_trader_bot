# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Ai::OpenAIClient, type: :service do
  let(:client) { described_class.new }
  let(:market_data) { create_test_market_data }
  let(:context) { { 'current_time' => '14:30', 'market_session' => 'Regular' } }

  describe '#initialize' do
    it 'sets default values' do
      expect(client.model).to eq('llama3.1:8b-instruct-q5_K_M')
      expect(client.use_ollama).to be true
      expect(client.enabled).to be true
    end

    it 'uses Windows Ollama URL in WSL environment' do
      expect(client.ollama_url).to eq('http://172.29.128.1:11434')
    end
  end

  describe '#test_connection' do
    context 'when Ollama is available' do
      before do
        allow(Net::HTTP).to receive(:get_response).and_return(
          double('response', code: '200', body: '{"models":[]}')
        )
      end

      it 'returns success' do
        result = client.test_connection
        expect(result[:success]).to be true
        expect(result[:message]).to include('Ollama connection successful')
      end
    end

    context 'when Ollama is not available' do
      before do
        allow(Net::HTTP).to receive(:get_response).and_raise(StandardError, 'Connection refused')
      end

      it 'returns failure' do
        result = client.test_connection
        expect(result[:success]).to be false
        expect(result[:error]).to include('Connection refused')
      end
    end
  end

  describe '#analyze_market_conditions' do
    before do
      allow(client).to receive(:make_request).and_return(mock_ai_response)
    end

    it 'calls make_request with market analysis prompt' do
      expect(client).to receive(:make_request).with(include('volatility'))
      client.analyze_market_conditions(market_data, context)
    end

    it 'returns success response' do
      result = client.analyze_market_conditions(market_data, context)
      expect(result[:success]).to be true
      expect(result[:data]).to eq('Test AI response')
    end
  end

  describe '#generate_trading_recommendations' do
    let(:signals) { create_test_signals }
    let(:portfolio_state) { create_test_portfolio_state }

    before do
      allow(client).to receive(:make_request).and_return(mock_ai_response)
    end

    it 'calls make_request with trading recommendations prompt' do
      expect(client).to receive(:make_request).with(include('trading signals'))
      client.generate_trading_recommendations(signals, market_data, portfolio_state)
    end

    it 'returns parsed recommendations' do
      result = client.generate_trading_recommendations(signals, market_data, portfolio_state)
      expect(result[:success]).to be true
      expect(result[:data]).to be_an(Array)
    end
  end

  describe '#make_ollama_request' do
    let(:prompt) { 'Test prompt' }

    before do
      allow(Net::HTTP).to receive(:start).and_return(
        double('response', code: '200', body: mock_ollama_response.to_json)
      )
    end

    it 'makes request to Ollama API' do
      expect(Net::HTTP).to receive(:start).with('172.29.128.1', 11434, read_timeout: 30)
      client.send(:make_ollama_request, prompt)
    end

    it 'returns parsed response' do
      result = client.send(:make_ollama_request, prompt)
      expect(result[:success]).to be true
      expect(result[:data]).to eq('Test Ollama response')
    end
  end

  describe '#enabled?' do
    it 'returns enabled status' do
      expect(client.enabled?).to be true
    end
  end
end
