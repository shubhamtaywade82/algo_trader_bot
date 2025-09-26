#!/usr/bin/env ruby
# frozen_string_literal: true

# Interactive AI Testing Script
# Allows you to test AI services with custom inputs

require 'net/http'
require 'json'
require 'uri'

class InteractiveAITester
  def initialize
    @base_url = 'http://localhost:3000'
  end

  def run
    puts '🤖 Interactive AI Services Tester'
    puts '=' * 40
    puts 'This script lets you test AI services with custom inputs'
    puts 'Make sure your Rails server is running on port 3000'
    puts ''

    loop do
      show_menu
      choice = gets.chomp.downcase

      case choice
      when '1'
        test_market_analysis
      when '2'
        test_trading_recommendations
      when '3'
        test_ai_decision
      when '4'
        test_ollama_connection
      when '5'
        test_custom_prompt
      when 'q', 'quit', 'exit'
        puts '👋 Goodbye!'
        break
      else
        puts '❌ Invalid choice. Please try again.'
      end

      puts "\n" + ('-' * 40) + "\n"
    end
  end

  private

  def show_menu
    puts 'Choose a test:'
    puts '1. Market Analysis'
    puts '2. Trading Recommendations'
    puts '3. AI Decision Engine'
    puts '4. Test Ollama Connection'
    puts '5. Custom Prompt Test'
    puts 'Q. Quit'
    print 'Enter your choice: '
  end

  def test_market_analysis
    puts "\n📊 Market Analysis Test"
    puts '-' * 25

    market_data = {
      volatility: get_float_input('Enter volatility (0.0-1.0): ', 0.25),
      trend_strength: get_float_input('Enter trend strength (0.0-1.0): ', 0.7),
      volume: get_int_input('Enter volume: ', 1_000_000),
      price_action: get_string_input('Enter price action (Bullish/Bearish/Neutral): ', 'Bullish')
    }

    context = {
      current_time: Time.now.strftime('%H:%M'),
      market_session: 'Regular',
      recent_performance: get_string_input('Enter recent performance: ', 'Positive')
    }

    puts "\n🔄 Sending request to AI..."
    response = make_request('POST', '/llm/analyze_market', {
                              market_data: market_data,
                              context: context
                            })

    display_response('Market Analysis', response)
  end

  def test_trading_recommendations
    puts "\n💡 Trading Recommendations Test"
    puts '-' * 30

    signals = [{
      strategy: get_string_input('Enter strategy name: ', 'OptionsScalper'),
      action: get_string_input('Enter action (BUY/SELL): ', 'BUY'),
      confidence: get_float_input('Enter confidence (0.0-1.0): ', 0.8),
      instrument: get_string_input('Enter instrument: ', 'NIFTY24000CE'),
      price: get_float_input('Enter price: ', 150.0)
    }]

    market_data = {
      volatility: get_float_input('Enter market volatility: ', 0.25),
      trend_strength: get_float_input('Enter trend strength: ', 0.7)
    }

    portfolio_state = {
      available_cash: get_int_input('Enter available cash: ', 100_000),
      current_positions: get_int_input('Enter current positions: ', 2),
      total_exposure: get_int_input('Enter total exposure: ', 50_000)
    }

    puts "\n🔄 Sending request to AI..."
    response = make_request('POST', '/llm/trading_recommendations', {
                              signals: signals,
                              market_data: market_data,
                              portfolio_state: portfolio_state
                            })

    display_response('Trading Recommendations', response)
  end

  def test_ai_decision
    puts "\n🎯 AI Decision Engine Test"
    puts '-' * 25

    market_data = {
      volatility: get_float_input('Enter volatility: ', 0.3),
      trend_strength: get_float_input('Enter trend strength: ', 0.6),
      volume: get_int_input('Enter volume: ', 1_500_000),
      price_action: get_string_input('Enter price action: ', 'Neutral')
    }

    signals = [{
      strategy: get_string_input('Enter strategy: ', 'TrendFollower'),
      action: get_string_input('Enter action: ', 'BUY'),
      confidence: get_float_input('Enter confidence: ', 0.75),
      instrument: get_string_input('Enter instrument: ', 'NIFTY24000PE'),
      price: get_float_input('Enter price: ', 120.0)
    }]

    portfolio_state = {
      available_cash: get_int_input('Enter available cash: ', 75_000),
      current_positions: get_int_input('Enter current positions: ', 1),
      total_exposure: get_int_input('Enter total exposure: ', 25_000)
    }

    puts "\n🔄 Sending request to AI..."
    response = make_request('POST', '/llm/ai_decision', {
                              market_data: market_data,
                              signals: signals,
                              portfolio_state: portfolio_state
                            })

    display_response('AI Decision', response)
  end

  def test_ollama_connection
    puts "\n🔗 Testing Ollama Connection"
    puts '-' * 28

    # Test direct Ollama connection
    begin
      uri = URI('http://172.29.128.1:11434/api/tags')
      http = Net::HTTP.new(uri.host, uri.port)
      http.read_timeout = 5
      http.open_timeout = 5

      request = Net::HTTP::Get.new(uri)
      response = http.request(request)

      if response.code.to_i == 200
        puts '✅ Ollama is accessible on Windows'
        models = begin
          JSON.parse(response.body)['models']
        rescue StandardError
          []
        end
        puts "📋 Available models: #{models.map { |m| m['name'] }.join(', ')}"
      else
        puts "❌ Ollama connection failed: HTTP #{response.code}"
      end
    rescue StandardError => e
      puts "❌ Ollama connection error: #{e.message}"
    end

    # Test through Rails API
    puts "\n🔄 Testing through Rails API..."
    response = make_request('POST', '/llm/test_ai_connection')
    display_response('AI Connection Test', response)
  end

  def test_custom_prompt
    puts "\n✏️  Custom Prompt Test"
    puts '-' * 20

    prompt = get_string_input('Enter your custom prompt: ', 'Analyze the current market conditions and provide trading insights.')

    puts "\n🔄 Sending custom prompt to AI..."
    response = make_request('POST', '/llm/custom_analysis', {
                              prompt: prompt
                            })

    display_response('Custom Analysis', response)
  end

  def get_float_input(prompt, default)
    print prompt
    input = gets.chomp
    input.empty? ? default : input.to_f
  rescue StandardError
    default
  end

  def get_int_input(prompt, default)
    print prompt
    input = gets.chomp
    input.empty? ? default : input.to_i
  rescue StandardError
    default
  end

  def get_string_input(prompt, default)
    print prompt
    input = gets.chomp
    input.empty? ? default : input
  end

  def make_request(method, endpoint, data = nil)
    uri = URI("#{@base_url}#{endpoint}")

    http = Net::HTTP.new(uri.host, uri.port)
    http.read_timeout = 30
    http.open_timeout = 10

    case method.upcase
    when 'GET'
      request = Net::HTTP::Get.new(uri)
    when 'POST'
      request = Net::HTTP::Post.new(uri)
      request['Content-Type'] = 'application/json'
      request.body = data.to_json if data
    end

    response = http.request(request)

    if response.code.to_i == 200
      parsed_response = JSON.parse(response.body)
      { success: true, data: parsed_response }
    else
      { success: false, error: "HTTP #{response.code}: #{response.body}" }
    end
  rescue StandardError => e
    { success: false, error: e.message }
  end

  def display_response(test_name, response)
    puts "\n📋 #{test_name} Results:"
    puts '=' * 30

    if response[:success]
      puts '✅ Success!'
      puts "\n📊 Response Data:"
      puts JSON.pretty_generate(response[:data])
    else
      puts '❌ Failed!'
      puts "\n🚨 Error: #{response[:error]}"
    end
  end
end

# Run the interactive tester
if __FILE__ == $0
  tester = InteractiveAITester.new
  tester.run
end
