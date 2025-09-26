# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Trading Flow Integration', type: :integration do
  let(:trading_engine) { Trading::Engine.new }
  let(:ai_client) { Ai::OpenAIClient.new }
  let(:decision_engine) { Ai::DecisionEngine.new }

  before do
    trading_engine.add_strategy(Strategy::OptionsScalper)
    allow(trading_engine).to receive(:sleep)
  end

  describe 'Complete Trading Flow' do
    it 'processes signals from strategy to execution' do
      # Mock strategy signals
      signals = [create_test_signals.first]
      allow(Strategy::OptionsScalper).to receive(:new).and_return(
        double('strategy', generate_signals: signals)
      )

      # Mock AI analysis
      allow(ai_client).to receive(:analyze_market_conditions)
        .and_return(mock_ai_response(data: 'Bullish market'))

      allow(decision_engine).to receive(:make_decision)
        .and_return({
                      success: true,
                      data: { decision: 'BUY', confidence: 0.8 }
                    })

      # Mock position management
      allow(Position::Sizer).to receive(:new).and_return(
        double('sizer', calculate_position_size: 100)
      )

      # Start trading engine
      trading_engine.start
      trading_engine.stop

      expect(trading_engine.running).to be false
    end
  end

  describe 'AI Integration Flow' do
    it 'integrates AI analysis with trading decisions' do
      market_data = create_test_market_data
      signals = create_test_signals
      portfolio_state = create_test_portfolio_state

      # Test market analysis
      market_result = ai_client.analyze_market_conditions(market_data)
      expect(market_result[:success]).to be true

      # Test trading recommendations
      recommendations = ai_client.generate_trading_recommendations(
        signals, market_data, portfolio_state
      )
      expect(recommendations[:success]).to be true

      # Test decision making
      decision = decision_engine.make_decision(market_data, signals, portfolio_state)
      expect(decision[:success]).to be true
      expect(decision[:data]).to include(:decision, :confidence)
    end
  end

  describe 'Risk Management Integration' do
    it 'integrates risk management with position sizing' do
      signal = create_test_signals.first
      portfolio_state = create_test_portfolio_state

      sizer = Position::Sizer.new
      size = sizer.calculate_position_size(signal, portfolio_state)

      expect(size).to be > 0
      expect(size).to be <= portfolio_state['available_cash']
    end
  end
end
