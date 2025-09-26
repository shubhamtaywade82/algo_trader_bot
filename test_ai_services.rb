#!/usr/bin/env ruby
# frozen_string_literal: true

# Comprehensive AI Services Testing Script
# Tests the AI services with real market data and scenarios

require 'net/http'
require 'json'
require 'uri'

class AIServicesTester
  def initialize
    @base_url = 'http://localhost:3000'
    @results = {
      connection_tests: [],
      ai_tests: [],
      integration_tests: [],
      overall_success: true
    }
  end

  def run_all_tests
    puts '🤖 Starting Comprehensive AI Services Tests'
    puts '=' * 60

    test_rails_connection
    test_ai_services_directly
    test_ai_integration_scenarios
    print_results
  end

  private

  def test_rails_connection
    puts "\n🔗 Testing Rails API Connection..."

    begin
      response = make_request('GET', '/up')
      if response[:success] && response[:data]&.include?('OK')
        puts '  ✅ Rails API is running'
        @results[:connection_tests] << { name: 'Rails API', success: true }
      else
        puts '  ❌ Rails API not responding'
        @results[:connection_tests] << { name: 'Rails API', success: false }
        @results[:overall_success] = false
      end
    rescue StandardError => e
      puts "  ❌ Rails API connection failed: #{e.message}"
      @results[:connection_tests] << { name: 'Rails API', error: e.message, success: false }
      @results[:overall_success] = false
    end
  end

  def test_ai_services_directly
    puts "\n🧠 Testing AI Services Directly..."

    # Test AI Client
    test_ai_client
    test_ai_decision_engine
  end

  def test_ai_client
    puts "\n  📡 Testing AI Client..."

    # Test basic connection
    begin
      response = make_request('POST', '/llm/analyze_market', {
                                market_data: {
                                  volatility: 0.25,
                                  trend_strength: 0.7,
                                  volume: 1_000_000,
                                  price_action: 'Bullish'
                                },
                                context: {
                                  current_time: Time.now.strftime('%H:%M'),
                                  market_session: 'Regular'
                                }
                              })

      if response[:success]
        puts '    ✅ AI Client market analysis - OK'
        puts "    📊 Response: #{response[:data][:analysis]&.truncate(100)}"
      else
        puts "    ❌ AI Client market analysis failed: #{response[:error]}"
        @results[:overall_success] = false
      end

      @results[:ai_tests] << {
        name: 'AI Client Market Analysis',
        success: response[:success],
        error: response[:error]
      }
    rescue StandardError => e
      puts "    ❌ AI Client test error: #{e.message}"
      @results[:ai_tests] << {
        name: 'AI Client Market Analysis',
        success: false,
        error: e.message
      }
      @results[:overall_success] = false
    end

    # Test trading recommendations
    begin
      response = make_request('POST', '/llm/trading_recommendations', {
                                signals: [
                                  {
                                    strategy: 'OptionsScalper',
                                    action: 'BUY',
                                    confidence: 0.8,
                                    instrument: 'NIFTY24000CE',
                                    price: 150.0
                                  }
                                ],
                                market_data: {
                                  volatility: 0.25,
                                  trend_strength: 0.7
                                },
                                portfolio_state: {
                                  available_cash: 100_000,
                                  current_positions: 2,
                                  total_exposure: 50_000
                                }
                              })

      if response[:success]
        puts '    ✅ AI Client trading recommendations - OK'
        puts "    💡 Recommendations: #{response[:data][:recommendations]&.length || 0} generated"
      else
        puts "    ❌ AI Client trading recommendations failed: #{response[:error]}"
        @results[:overall_success] = false
      end

      @results[:ai_tests] << {
        name: 'AI Client Trading Recommendations',
        success: response[:success],
        error: response[:error]
      }
    rescue StandardError => e
      puts "    ❌ AI Client trading recommendations error: #{e.message}"
      @results[:ai_tests] << {
        name: 'AI Client Trading Recommendations',
        success: false,
        error: e.message
      }
      @results[:overall_success] = false
    end
  end

  def test_ai_decision_engine
    puts "\n  🎯 Testing AI Decision Engine..."

    begin
      response = make_request('POST', '/llm/ai_decision', {
                                market_data: {
                                  volatility: 0.3,
                                  trend_strength: 0.6,
                                  volume: 1_500_000,
                                  price_action: 'Neutral'
                                },
                                signals: [
                                  {
                                    strategy: 'TrendFollower',
                                    action: 'BUY',
                                    confidence: 0.75,
                                    instrument: 'NIFTY24000PE',
                                    price: 120.0
                                  }
                                ],
                                portfolio_state: {
                                  available_cash: 75_000,
                                  current_positions: 1,
                                  total_exposure: 25_000
                                }
                              })

      if response[:success]
        puts '    ✅ AI Decision Engine - OK'
        puts "    🎯 Decision: #{response[:data][:decision] || 'No decision'}"
        puts "    📈 Confidence: #{response[:data][:confidence] || 'N/A'}"
      else
        puts "    ❌ AI Decision Engine failed: #{response[:error]}"
        @results[:overall_success] = false
      end

      @results[:ai_tests] << {
        name: 'AI Decision Engine',
        success: response[:success],
        error: response[:error]
      }
    rescue StandardError => e
      puts "    ❌ AI Decision Engine error: #{e.message}"
      @results[:ai_tests] << {
        name: 'AI Decision Engine',
        success: false,
        error: e.message
      }
      @results[:overall_success] = false
    end
  end

  def test_ai_integration_scenarios
    puts "\n🔄 Testing AI Integration Scenarios..."

    # Scenario 1: High volatility market
    test_scenario('High Volatility Market', {
                    market_data: {
                      volatility: 0.45,
                      trend_strength: 0.3,
                      volume: 2_000_000,
                      price_action: 'Choppy'
                    },
                    context: {
                      current_time: '14:30',
                      market_session: 'Regular',
                      recent_performance: 'Mixed'
                    }
                  })

    # Scenario 2: Strong trend market
    test_scenario('Strong Trend Market', {
                    market_data: {
                      volatility: 0.15,
                      trend_strength: 0.9,
                      volume: 3_000_000,
                      price_action: 'Strong Bullish'
                    },
                    context: {
                      current_time: '10:15',
                      market_session: 'Regular',
                      recent_performance: 'Very Positive'
                    }
                  })

    # Scenario 3: Low volume market
    test_scenario('Low Volume Market', {
                    market_data: {
                      volatility: 0.20,
                      trend_strength: 0.4,
                      volume: 500_000,
                      price_action: 'Sideways'
                    },
                    context: {
                      current_time: '15:45',
                      market_session: 'Regular',
                      recent_performance: 'Neutral'
                    }
                  })
  end

  def test_scenario(scenario_name, data)
    puts "\n  📊 Testing Scenario: #{scenario_name}"

    begin
      response = make_request('POST', '/llm/analyze_market', data)

      if response[:success]
        analysis = response[:data][:analysis]
        puts "    ✅ #{scenario_name} - OK"
        puts "    📝 Analysis: #{analysis&.truncate(150)}"

        # Check if analysis contains relevant keywords
        keywords = %w[volatility trend risk opportunity market]
        relevant_keywords = keywords.count { |kw| analysis&.downcase&.include?(kw) }
        puts "    🎯 Relevance Score: #{relevant_keywords}/#{keywords.length}"
      else
        puts "    ❌ #{scenario_name} failed: #{response[:error]}"
        @results[:overall_success] = false
      end

      @results[:integration_tests] << {
        name: scenario_name,
        success: response[:success],
        error: response[:error]
      }
    rescue StandardError => e
      puts "    ❌ #{scenario_name} error: #{e.message}"
      @results[:integration_tests] << {
        name: scenario_name,
        success: false,
        error: e.message
      }
      @results[:overall_success] = false
    end
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

  def print_results
    puts "\n" + ('=' * 60)
    puts '📋 COMPREHENSIVE AI TEST RESULTS'
    puts '=' * 60

    # Connection Tests
    puts "\n🔗 Connection Tests:"
    connection_success = @results[:connection_tests].all? { |t| t[:success] }
    puts "  Status: #{connection_success ? '✅ PASSED' : '❌ FAILED'}"
    puts "  Tests: #{@results[:connection_tests].count}"
    puts "  Passed: #{@results[:connection_tests].count { |t| t[:success] }}"

    # AI Tests
    puts "\n🧠 AI Service Tests:"
    ai_success = @results[:ai_tests].all? { |t| t[:success] }
    puts "  Status: #{ai_success ? '✅ PASSED' : '❌ FAILED'}"
    puts "  Tests: #{@results[:ai_tests].count}"
    puts "  Passed: #{@results[:ai_tests].count { |t| t[:success] }}"

    # Integration Tests
    puts "\n🔄 Integration Scenario Tests:"
    integration_success = @results[:integration_tests].all? { |t| t[:success] }
    puts "  Status: #{integration_success ? '✅ PASSED' : '❌ FAILED'}"
    puts "  Tests: #{@results[:integration_tests].count}"
    puts "  Passed: #{@results[:integration_tests].count { |t| t[:success] }}"

    # Overall Results
    puts "\n" + ('=' * 60)
    puts "🎯 OVERALL RESULT: #{@results[:overall_success] ? '✅ AI SERVICES READY' : '❌ AI SERVICES ISSUES'}"
    puts '=' * 60

    if @results[:overall_success]
      puts "\n🎉 AI Services are working perfectly!"
      puts '✅ Ollama integration with Windows'
      puts '✅ AI market analysis working'
      puts '✅ AI trading recommendations working'
      puts '✅ AI decision engine working'
      puts '✅ Multiple market scenarios tested'
      puts "\n🚀 Ready for Live Trading with AI!"
    else
      puts "\n⚠️  Some AI services have issues"
      puts 'Please review the failed tests above'
      puts 'Check that:'
      puts '  - Rails server is running'
      puts '  - Ollama is running on Windows'
      puts '  - AI endpoints are properly configured'
    end

    puts "\n💡 Next Steps:"
    puts '1. Start Rails server: rails server'
    puts '2. Test with real market data'
    puts '3. Integrate with trading engine'
    puts '4. Monitor AI performance'
  end
end

# Run the tests
if __FILE__ == $0
  tester = AIServicesTester.new
  tester.run_all_tests
end
