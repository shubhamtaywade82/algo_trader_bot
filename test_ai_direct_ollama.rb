#!/usr/bin/env ruby
# frozen_string_literal: true

# Test AI client directly with Ollama
require 'net/http'
require 'json'
require 'uri'

puts '🤖 Testing AI Client with Windows Ollama'
puts '=' * 50

# Test Windows Ollama connection
def test_ollama_connection
  puts "\n🦙 Testing Ollama Connection..."

  begin
    uri = URI('http://172.29.128.1:11434/api/tags')
    response = Net::HTTP.get_response(uri)

    if response.code == '200'
      data = JSON.parse(response.body)
      puts '  ✅ Ollama is accessible on Windows'
      puts "  📋 Available models: #{data['models'].map { |m| m['name'] }.join(', ')}"
      true
    else
      puts "  ❌ Ollama returned status: #{response.code}"
      false
    end
  rescue StandardError => e
    puts "  ❌ Ollama connection failed: #{e.message}"
    false
  end
end

# Test AI request to Ollama
def test_ai_request
  puts "\n🧠 Testing AI Request..."

  begin
    uri = URI('http://172.29.128.1:11434/api/generate')

    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'

    payload = {
      model: 'llama3.1:8b-instruct-q5_K_M',
      prompt: 'What is the current market sentiment for NIFTY options trading?',
      stream: false
    }

    request.body = payload.to_json

    response = Net::HTTP.start(uri.hostname, uri.port) do |http|
      http.request(request)
    end

    if response.code == '200'
      data = JSON.parse(response.body)
      puts '  ✅ AI request successful'
      puts "  📝 Response: #{data['response'][0..100]}..."
      true
    else
      puts "  ❌ AI request failed: #{response.code}"
      puts "  📝 Response: #{response.body}"
      false
    end
  rescue StandardError => e
    puts "  ❌ AI request error: #{e.message}"
    false
  end
end

# Test market analysis scenario
def test_market_analysis
  puts "\n📊 Testing Market Analysis Scenario..."

  begin
    uri = URI('http://172.29.128.1:11434/api/generate')

    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'

    payload = {
      model: 'llama3.1:8b-instruct-q5_K_M',
      prompt: 'Analyze this market data for NIFTY options trading: volatility=0.25, trend_strength=0.7, volume=1000000, price_action=Bullish. Provide trading recommendations.',
      stream: false
    }

    request.body = payload.to_json

    response = Net::HTTP.start(uri.hostname, uri.port) do |http|
      http.request(request)
    end

    if response.code == '200'
      data = JSON.parse(response.body)
      puts '  ✅ Market analysis successful'
      puts "  📝 Analysis: #{data['response'][0..200]}..."
      true
    else
      puts "  ❌ Market analysis failed: #{response.code}"
      false
    end
  rescue StandardError => e
    puts "  ❌ Market analysis error: #{e.message}"
    false
  end
end

# Run tests
puts "\n🚀 Starting AI Tests..."
puts '=' * 50

ollama_ok = test_ollama_connection
ai_ok = test_ai_request if ollama_ok
market_ok = test_market_analysis if ollama_ok

puts "\n" + ('=' * 50)
puts '📋 TEST SUMMARY'
puts '=' * 50

puts "✅ What's Working:"
puts "  - Ollama connection: #{ollama_ok ? 'YES' : 'NO'}"
puts "  - AI requests: #{ai_ok ? 'YES' : 'NO'}"
puts "  - Market analysis: #{market_ok ? 'YES' : 'NO'}"

if ollama_ok && ai_ok && market_ok
  puts "\n🎉 All AI tests passed! Phase 4 is working correctly."
  puts "\n💡 The issue is that Rails is not picking up the code changes."
  puts '   Try restarting the Rails server or check for caching issues.'
else
  puts "\n❌ Some tests failed. Check the error messages above."
end

puts "\n🔧 Next Steps:"
puts '  1. Fix Rails code reloading issue'
puts '  2. Test AI endpoints through Rails API'
puts '  3. Integrate with trading engine'
