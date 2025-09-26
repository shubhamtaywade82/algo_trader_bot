# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Ai::DecisionEngine, type: :service do
  let(:engine) { described_class.new }
  let(:market_data) { create_test_market_data }
  let(:signals) { create_test_signals }
  let(:portfolio_state) { create_test_portfolio_state }

  describe '#initialize' do
    it 'sets default values' do
      expect(engine.enabled).to be true
      expect(engine.confidence_threshold).to eq(0.7)
      expect(engine.analysis_interval).to eq(300)
    end
  end

  describe '#make_decision' do
    before do
      allow(engine).to receive(:analyze_market_conditions).and_return(
        { success: true, data: { 'market_condition' => 'Bullish' } }
      )
      allow(engine.openai_client).to receive(:generate_trading_recommendations).and_return(
        { success: true, data: [{ 'action' => 'BUY', 'confidence' => 0.8, 'reasoning' => 'Strong signal' }] }
      )
    end

    it 'analyzes market conditions' do
      expect(engine).to receive(:analyze_market_conditions).with(market_data)
      engine.make_decision(market_data, signals, portfolio_state)
    end

    it 'generates trading recommendations' do
      expect(engine.openai_client).to receive(:generate_trading_recommendations)
        .with(signals, market_data, portfolio_state)
      engine.make_decision(market_data, signals, portfolio_state)
    end

    it 'returns decision with confidence and reasoning' do
      result = engine.make_decision(market_data, signals, portfolio_state)
      expect(result[:success]).to be true
      expect(result[:data][:decision]).to eq('BUY')
      expect(result[:data][:confidence]).to eq(0.8)
      expect(result[:data][:reasoning]).to eq('Strong signal')
    end
  end

  describe '#enhance_signals' do
    before do
      allow(engine).to receive(:should_analyze?).and_return(true)
      allow(engine.openai_client).to receive(:generate_trading_recommendations).and_return(
        { success: true, data: { recommendations: 'High confidence signal' } }
      )
    end

    it 'enhances signals with AI analysis' do
      enhanced = engine.enhance_signals(signals, market_data, portfolio_state)
      expect(enhanced).to be_an(Array)
      expect(enhanced.first[:ai_insights]).to be_present
    end
  end

  describe '#analyze_market_conditions' do
    before do
      allow(engine.openai_client).to receive(:analyze_market_conditions).and_return(
        { success: true, data: 'Market analysis' }
      )
    end

    it 'calls OpenAI client for market analysis' do
      expect(engine.openai_client).to receive(:analyze_market_conditions)
        .with(market_data, {})
      engine.analyze_market_conditions(market_data)
    end

    it 'caches analysis results' do
      result1 = engine.analyze_market_conditions(market_data)
      result2 = engine.analyze_market_conditions(market_data)
      expect(result1).to eq(result2)
    end
  end

  describe '#assess_risk' do
    let(:positions) { [create(:trading_position)] }
    let(:risk_metrics) { { 'max_drawdown' => 0.1, 'var' => 0.05 } }

    before do
      allow(engine.openai_client).to receive(:make_request).and_return(
        { success: true, data: 'Risk assessment: Low risk' }
      )
    end

    it 'assesses risk for positions' do
      result = engine.assess_risk(positions, market_data, risk_metrics)
      expect(result[:success]).to be true
      expect(result[:data]).to include('risk_level')
    end
  end

  describe '#enabled?' do
    it 'returns enabled status' do
      expect(engine.enabled?).to be true
    end
  end
end
