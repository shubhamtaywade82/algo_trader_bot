# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'LlmController', type: :request do
  describe 'GET /llm/funds' do
    it 'returns funds data' do
      get '/llm/funds'

      expect(response).to have_http_status(:ok)
      expect(json_response).to include(
        'available_balance',
        'sod_limit',
        'withdrawable_balance'
      )
    end
  end

  describe 'GET /llm/positions' do
    it 'returns positions data' do
      get '/llm/positions'

      expect(response).to have_http_status(:ok)
      expect(json_response).to be_an(Array)
    end
  end

  describe 'GET /llm/orders' do
    it 'returns orders data' do
      get '/llm/orders'

      expect(response).to have_http_status(:ok)
      expect(json_response).to be_an(Array)
    end
  end

  describe 'GET /llm/spot' do
    it 'returns spot price for symbol' do
      get '/llm/spot', params: { underlying: 'NIFTY' }

      expect(response).to have_http_status(:ok)
      expect(json_response).to include('symbol', 'spot')
    end
  end

  describe 'POST /llm/analyze_market' do
    let(:market_data) { create_test_market_data }
    let(:context) { { 'current_time' => '14:30', 'market_session' => 'Regular' } }

    before do
      allow_any_instance_of(Ai::OpenAIClient).to receive(:analyze_market_conditions)
        .and_return(mock_ai_response)
    end

    it 'analyzes market conditions' do
      post '/llm/analyze_market', params: {
        market_data: market_data,
        context: context
      }

      expect(response).to have_http_status(:ok)
      expect(json_response).to include('analysis')
    end
  end

  describe 'POST /llm/trading_recommendations' do
    let(:signals) { create_test_signals }
    let(:market_data) { create_test_market_data }
    let(:portfolio_state) { create_test_portfolio_state }

    before do
      allow_any_instance_of(Ai::OpenAIClient).to receive(:generate_trading_recommendations)
        .and_return(mock_ai_response(data: [{ 'action' => 'BUY', 'confidence' => 0.8 }]))
    end

    it 'generates trading recommendations' do
      post '/llm/trading_recommendations', params: {
        signals: signals,
        market_data: market_data,
        portfolio_state: portfolio_state
      }

      expect(response).to have_http_status(:ok)
      expect(json_response).to include('recommendations')
    end
  end

  describe 'POST /llm/ai_decision' do
    let(:market_data) { create_test_market_data }
    let(:signals) { create_test_signals }
    let(:portfolio_state) { create_test_portfolio_state }

    before do
      allow_any_instance_of(Ai::DecisionEngine).to receive(:make_decision)
        .and_return({
          success: true,
          data: {
            decision: 'BUY',
            confidence: 0.8,
            reasoning: 'Strong bullish signal'
          }
        })
    end

    it 'makes AI trading decision' do
      post '/llm/ai_decision', params: {
        market_data: market_data,
        signals: signals,
        portfolio_state: portfolio_state
      }

      expect(response).to have_http_status(:ok)
      expect(json_response).to include('decision', 'confidence', 'reasoning')
    end
  end

  describe 'GET /llm/test_ai_connection' do
    before do
      allow_any_instance_of(Ai::OpenAIClient).to receive(:test_connection)
        .and_return(mock_ai_response(message: 'AI connection successful'))
    end

    it 'tests AI connection' do
      get '/llm/test_ai_connection'

      expect(response).to have_http_status(:ok)
      expect(json_response).to include('message')
    end
  end

  describe 'POST /llm/custom_analysis' do
    let(:prompt) { 'Analyze the current market conditions' }

    before do
      allow_any_instance_of(Ai::OpenAIClient).to receive(:make_request)
        .and_return(mock_ai_response(data: 'Custom analysis result'))
    end

    it 'performs custom AI analysis' do
      post '/llm/custom_analysis', params: { prompt: prompt }

      expect(response).to have_http_status(:ok)
      expect(json_response).to include('analysis')
    end
  end
end
