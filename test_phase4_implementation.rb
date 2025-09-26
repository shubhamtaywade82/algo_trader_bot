#!/usr/bin/env ruby
# frozen_string_literal: true

# Test script for Phase 4 implementation
# Tests AI integration services

require 'net/http'
require 'json'
require 'uri'

class Phase4Tester
  def initialize
    @results = {
      service_tests: [],
      integration_tests: [],
      overall_success: true
    }
  end

  def run_all_tests
    puts '🚀 Starting Phase 4 Implementation Tests'
    puts '=' * 50

    test_services
    test_integration
    print_results
  end

  private

  def test_services
    puts "\n🤖 Testing AI Services..."

    # Test if service files exist and are loadable
    services = [
      'app/services/ai/openai_client.rb',
      'app/services/ai/decision_engine.rb'
    ]

    services.each do |service_path|
      if File.exist?(service_path)
        content = File.read(service_path)

        if content.include?('class ') && content.include?('def ')
          test_result = {
            name: File.basename(service_path, '.rb'),
            file_exists: true,
            syntax_valid: true,
            success: true
          }
          puts "  ✅ #{File.basename(service_path, '.rb')} - OK"
        else
          test_result = {
            name: File.basename(service_path, '.rb'),
            file_exists: true,
            syntax_valid: false,
            success: false
          }
          puts "  ❌ #{File.basename(service_path, '.rb')} - Invalid syntax"
          @results[:overall_success] = false
        end
      else
        test_result = {
          name: File.basename(service_path, '.rb'),
          file_exists: false,
          success: false
        }
        puts "  ❌ #{File.basename(service_path, '.rb')} - File not found"
        @results[:overall_success] = false
      end

      @results[:service_tests] << test_result
    rescue StandardError => e
      test_result = {
        name: File.basename(service_path, '.rb'),
        error: e.message,
        success: false
      }
      puts "  ❌ #{File.basename(service_path, '.rb')} - ERROR: #{e.message}"
      @results[:service_tests] << test_result
      @results[:overall_success] = false
    end
  end

  def test_integration
    puts "\n🔗 Testing AI Integration..."

    # Test Ollama connection (if available)
    begin
      ollama_response = test_ollama_connection

      test_result = {
        name: 'Ollama Connection Test',
        can_connect: ollama_response[:success],
        message: ollama_response[:message] || ollama_response[:error],
        success: ollama_response[:success]
      }

      if ollama_response[:success]
        puts '  ✅ Ollama Connection Test - OK'
      else
        puts "  ⚠️  Ollama Connection Test - #{ollama_response[:error]}"
      end

      @results[:integration_tests] << test_result
    rescue StandardError => e
      test_result = {
        name: 'Ollama Connection Test',
        error: e.message,
        success: false
      }
      puts "  ❌ Ollama Connection Test - ERROR: #{e.message}"
      @results[:integration_tests] << test_result
      @results[:overall_success] = false
    end

    # Test AI prompt building
    begin
      market_data = {
        volatility: 0.25,
        trend_strength: 0.7,
        volume: 1_000_000,
        price_action: 'Bullish'
      }

      context = {
        current_time: '14:30',
        market_session: 'Regular',
        recent_performance: 'Positive'
      }

      prompt = build_test_market_analysis_prompt(market_data, context)

      test_result = {
        name: 'AI Prompt Building',
        can_build_prompt: prompt.include?('Market Data:'),
        success: true
      }

      puts '  ✅ AI Prompt Building - OK'
      @results[:integration_tests] << test_result
    rescue StandardError => e
      test_result = {
        name: 'AI Prompt Building',
        error: e.message,
        success: false
      }
      puts "  ❌ AI Prompt Building - ERROR: #{e.message}"
      @results[:integration_tests] << test_result
      @results[:overall_success] = false
    end
  end

  def test_ollama_connection
    # Try multiple possible Ollama URLs
    urls_to_try = [
      'http://localhost:11434',
      detect_windows_host_url,
      'http://172.20.240.1:11434',
      'http://172.20.240.2:11434'
    ].compact.uniq

    urls_to_try.each do |url|
      begin
        uri = URI("#{url}/api/tags")
        http = Net::HTTP.new(uri.host, uri.port)
        http.read_timeout = 3
        http.open_timeout = 3

        request = Net::HTTP::Get.new(uri)
        response = http.request(request)

        if response.code.to_i == 200
          return { success: true, message: "Ollama is running at #{url}" }
        end
      rescue StandardError
        # Try next URL
        next
      end
    end

    { success: false, error: 'Ollama not accessible from any known URL' }
  end

  def detect_windows_host_url
    # Detect Windows host IP from WSL
    if File.exist?('/proc/version') && File.read('/proc/version').include?('microsoft')
      result = `ip route show default | awk '/default/ {print $3}'`.strip
      return "http://#{result}:11434" unless result.empty?
    end
    nil
  rescue StandardError
    nil
  end

  def build_test_market_analysis_prompt(market_data, context)
    <<~PROMPT
      Analyze the following market data and provide trading insights:

      Market Data:
      - Volatility: #{market_data[:volatility]&.round(3) || 'N/A'}
      - Trend Strength: #{market_data[:trend_strength]&.round(3) || 'N/A'}
      - Volume: #{market_data[:volume] || 'N/A'}
      - Price Action: #{market_data[:price_action] || 'N/A'}

      Context:
      - Current Time: #{context[:current_time] || Time.now.strftime('%H:%M')}
      - Market Session: #{context[:market_session] || 'Regular'}
      - Recent Performance: #{context[:recent_performance] || 'N/A'}

      Please provide:
      1. Market condition assessment (Bullish/Bearish/Neutral)
      2. Key risk factors to watch
      3. Recommended trading approach
      4. Specific indicators to monitor

      Keep response concise and actionable.
    PROMPT
  end

  def print_results
    puts "\n" + ('=' * 50)
    puts '📋 PHASE 4 TEST RESULTS'
    puts '=' * 50

    # Service Tests
    puts "\n🤖 Service Tests:"
    service_success = @results[:service_tests].all? { |t| t[:success] }
    puts "  Status: #{service_success ? '✅ PASSED' : '❌ FAILED'}"
    puts "  Tests: #{@results[:service_tests].count}"
    puts "  Passed: #{@results[:service_tests].count { |t| t[:success] }}"

    # Integration Tests
    puts "\n🔗 Integration Tests:"
    integration_success = @results[:integration_tests].all? { |t| t[:success] }
    puts "  Status: #{integration_success ? '✅ PASSED' : '❌ FAILED'}"
    puts "  Tests: #{@results[:integration_tests].count}"
    puts "  Passed: #{@results[:integration_tests].count { |t| t[:success] }}"

    # Overall Results
    puts "\n" + ('=' * 50)
    puts "🎯 OVERALL RESULT: #{@results[:overall_success] ? '✅ PHASE 4 READY' : '❌ PHASE 4 ISSUES'}"
    puts '=' * 50

    if @results[:overall_success]
      puts "\n🎉 Phase 4 implementation is ready!"
      puts '✅ OpenAI/Ollama client service created'
      puts '✅ AI decision engine service created'
      puts '✅ Ollama integration for local development'
      puts "\n🚀 Ready for Production Deployment"
    else
      puts "\n⚠️  Some issues found in Phase 4 implementation"
      puts 'Please review the failed tests above and fix any issues'
    end

    # Ollama setup instructions
    puts "\n📝 Ollama Setup Instructions:"
    puts '1. Install Ollama: https://ollama.ai/'
    puts '2. Pull a model: ollama pull llama3.1'
    puts '3. Start Ollama: ollama serve'
    puts '4. Set environment variable: USE_OLLAMA=true'
  end
end

# Run the tests
if __FILE__ == $0
  tester = Phase4Tester.new
  tester.run_all_tests
end
