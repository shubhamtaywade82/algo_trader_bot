#!/usr/bin/env ruby
# frozen_string_literal: true

# Direct test of AI services without Rails

require_relative 'app/services/ai'
require_relative 'app/services/ai/openai_client'
require_relative 'app/services/ai/decision_engine'

puts '🤖 Testing AI Services Directly'
puts '=' * 40

# Test AI Client
puts "\n📡 Testing AI Client..."
begin
  ai_client = AI::OpenAIClient.new
  puts '  ✅ AI Client created successfully'
  puts "  🔗 Using Ollama: #{ai_client.use_ollama?}"
  puts "  🌐 Ollama URL: #{ai_client.ollama_url}"

  # Test connection
  result = ai_client.test_connection
  if result[:success]
    puts "  ✅ Connection test: #{result[:message]}"
  else
    puts "  ❌ Connection test failed: #{result[:error]}"
  end
rescue StandardError => e
  puts "  ❌ AI Client error: #{e.message}"
end

# Test AI Decision Engine
puts "\n🎯 Testing AI Decision Engine..."
begin
  decision_engine = AI::DecisionEngine.new
  puts '  ✅ Decision Engine created successfully'

  # Test with sample data
  market_data = {
    volatility: 0.25,
    trend_strength: 0.7,
    volume: 1_000_000,
    price_action: 'Bullish'
  }

  signals = [{
    strategy: 'OptionsScalper',
    action: 'BUY',
    confidence: 0.8,
    instrument: 'NIFTY24000CE',
    price: 150.0
  }]

  portfolio_state = {
    available_cash: 100_000,
    current_positions: 2,
    total_exposure: 50_000
  }

  result = decision_engine.make_decision(market_data, signals, portfolio_state)
  if result[:success]
    puts "  ✅ Decision made: #{result[:data][:decision]}"
    puts "  📈 Confidence: #{result[:data][:confidence]}"
  else
    puts "  ❌ Decision failed: #{result[:error]}"
  end
rescue StandardError => e
  puts "  ❌ Decision Engine error: #{e.message}"
end

puts "\n🎉 Direct AI Services Test Complete!"
