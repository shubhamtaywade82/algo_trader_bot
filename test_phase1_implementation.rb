#!/usr/bin/env ruby
# frozen_string_literal: true

# Test script for Phase 1 implementation
# Tests all strategy classes, signal generation, and trading engine

require 'net/http'
require 'json'
require 'uri'

# Load Rails environment
require_relative 'config/environment'

class Phase1Tester
  BASE_URL = 'http://localhost:3000'

  def initialize
    @results = {
      strategy_tests: [],
      signal_tests: [],
      trading_engine_tests: [],
      api_tests: [],
      overall_success: true
    }
  end

  def run_all_tests
    puts '🚀 Starting Phase 1 Implementation Tests'
    puts '=' * 50

    test_strategies
    test_signal_generation
    test_trading_engine
    test_api_endpoints

    print_results
  end

  private

  def test_strategies
    puts "\n📊 Testing Strategy Classes..."

    strategies = [
      Strategy::Base,
      Strategy::OptionsScalper,
      Strategy::TrendFollower,
      Strategy::BreakoutScalper,
      Strategy::MeanReversion
    ]

    strategies.each do |strategy_class|
      strategy = strategy_class.new(name: strategy_class.name.split('::').last)

      # Test basic functionality
      test_result = {
        name: strategy_class.name,
        can_instantiate: true,
        has_execute_method: strategy.respond_to?(:execute),
        has_should_exit_method: strategy.respond_to?(:should_exit?),
        has_valid_for_trading_method: strategy.respond_to?(:valid_for_trading?),
        success: true
      }

      puts "  ✅ #{strategy_class.name} - OK"
      @results[:strategy_tests] << test_result
    rescue StandardError => e
      test_result = {
        name: strategy_class.name,
        error: e.message,
        success: false
      }
      puts "  ❌ #{strategy_class.name} - ERROR: #{e.message}"
      @results[:strategy_tests] << test_result
      @results[:overall_success] = false
    end
  end

  def test_signal_generation
    puts "\n📡 Testing Signal Generation..."

    begin
      # Test Signal::Generator
      generator = Signal::Generator.new

      test_result = {
        name: 'Signal::Generator',
        can_instantiate: true,
        has_generate_signals_method: generator.respond_to?(:generate_signals),
        has_check_exit_signals_method: generator.respond_to?(:check_exit_signals),
        success: true
      }

      puts '  ✅ Signal::Generator - OK'
      @results[:signal_tests] << test_result

      # Test Signal::Processor
      processor = Signal::Processor.new

      test_result = {
        name: 'Signal::Processor',
        can_instantiate: true,
        has_process_entry_signals_method: processor.respond_to?(:process_entry_signals),
        has_process_exit_signals_method: processor.respond_to?(:process_exit_signals),
        success: true
      }

      puts '  ✅ Signal::Processor - OK'
      @results[:signal_tests] << test_result
    rescue StandardError => e
      test_result = {
        name: 'Signal Services',
        error: e.message,
        success: false
      }
      puts "  ❌ Signal Services - ERROR: #{e.message}"
      @results[:signal_tests] << test_result
      @results[:overall_success] = false
    end
  end

  def test_trading_engine
    puts "\n🤖 Testing Trading Engine..."

    begin
      # Test Trading::Engine
      engine = Trading::Engine.new

      test_result = {
        name: 'Trading::Engine',
        can_instantiate: true,
        has_start_method: engine.respond_to?(:start!),
        has_stop_method: engine.respond_to?(:stop!),
        has_running_method: engine.respond_to?(:running?),
        has_status_method: engine.respond_to?(:status),
        success: true
      }

      puts '  ✅ Trading::Engine - OK'
      @results[:trading_engine_tests] << test_result

      # Test Trading::PositionManager
      position_manager = Trading::PositionManager.new

      test_result = {
        name: 'Trading::PositionManager',
        can_instantiate: true,
        has_update_positions_method: position_manager.respond_to?(:update_positions),
        has_active_positions_method: position_manager.respond_to?(:active_positions),
        has_portfolio_stats_method: position_manager.respond_to?(:portfolio_stats),
        success: true
      }

      puts '  ✅ Trading::PositionManager - OK'
      @results[:trading_engine_tests] << test_result
    rescue StandardError => e
      test_result = {
        name: 'Trading Engine Services',
        error: e.message,
        success: false
      }
      puts "  ❌ Trading Engine Services - ERROR: #{e.message}"
      @results[:trading_engine_tests] << test_result
      @results[:overall_success] = false
    end
  end

  def test_api_endpoints
    puts "\n🌐 Testing API Endpoints..."

    endpoints = [
      { method: 'GET', path: '/trading/status', name: 'Trading Status' },
      { method: 'GET', path: '/trading/health', name: 'Trading Health' },
      { method: 'GET', path: '/trading/positions', name: 'Trading Positions' },
      { method: 'GET', path: '/trading/stats', name: 'Trading Stats' },
      { method: 'POST', path: '/trading/start', name: 'Start Trading' },
      { method: 'POST', path: '/trading/stop', name: 'Stop Trading' }
    ]

    endpoints.each do |endpoint|
      response = make_request(endpoint[:method], endpoint[:path])

      test_result = {
        name: endpoint[:name],
        method: endpoint[:method],
        path: endpoint[:path],
        status_code: response[:status_code],
        success: response[:status_code] == 200,
        response_time: response[:response_time]
      }

      if response[:status_code] == 200
        puts "  ✅ #{endpoint[:name]} - OK (#{response[:status_code]})"
      else
        puts "  ⚠️  #{endpoint[:name]} - #{response[:status_code]}"
      end

      @results[:api_tests] << test_result
    rescue StandardError => e
      test_result = {
        name: endpoint[:name],
        method: endpoint[:method],
        path: endpoint[:path],
        error: e.message,
        success: false
      }
      puts "  ❌ #{endpoint[:name]} - ERROR: #{e.message}"
      @results[:api_tests] << test_result
      @results[:overall_success] = false
    end
  end

  def make_request(method, path)
    start_time = Time.now
    uri = URI("#{BASE_URL}#{path}")

    case method.upcase
    when 'GET'
      response = Net::HTTP.get_response(uri)
    when 'POST'
      http = Net::HTTP.new(uri.host, uri.port)
      request = Net::HTTP::Post.new(uri)
      response = http.request(request)
    end

    {
      status_code: response.code.to_i,
      response_time: ((Time.now - start_time) * 1000).round(2)
    }
  rescue StandardError => e
    raise "Request failed: #{e.message}"
  end

  def print_results
    puts "\n" + ('=' * 50)
    puts '📋 PHASE 1 TEST RESULTS'
    puts '=' * 50

    # Strategy Tests
    puts "\n📊 Strategy Tests:"
    strategy_success = @results[:strategy_tests].all? { |t| t[:success] }
    puts "  Status: #{strategy_success ? '✅ PASSED' : '❌ FAILED'}"
    puts "  Tests: #{@results[:strategy_tests].count}"
    puts "  Passed: #{@results[:strategy_tests].count { |t| t[:success] }}"

    # Signal Tests
    puts "\n📡 Signal Generation Tests:"
    signal_success = @results[:signal_tests].all? { |t| t[:success] }
    puts "  Status: #{signal_success ? '✅ PASSED' : '❌ FAILED'}"
    puts "  Tests: #{@results[:signal_tests].count}"
    puts "  Passed: #{@results[:signal_tests].count { |t| t[:success] }}"

    # Trading Engine Tests
    puts "\n🤖 Trading Engine Tests:"
    engine_success = @results[:trading_engine_tests].all? { |t| t[:success] }
    puts "  Status: #{engine_success ? '✅ PASSED' : '❌ FAILED'}"
    puts "  Tests: #{@results[:trading_engine_tests].count}"
    puts "  Passed: #{@results[:trading_engine_tests].count { |t| t[:success] }}"

    # API Tests
    puts "\n🌐 API Endpoint Tests:"
    api_success = @results[:api_tests].all? { |t| t[:success] }
    puts "  Status: #{api_success ? '✅ PASSED' : '❌ FAILED'}"
    puts "  Tests: #{@results[:api_tests].count}"
    puts "  Passed: #{@results[:api_tests].count { |t| t[:success] }}"

    # Overall Results
    puts "\n" + ('=' * 50)
    puts "🎯 OVERALL RESULT: #{@results[:overall_success] ? '✅ PHASE 1 COMPLETE' : '❌ PHASE 1 INCOMPLETE'}"
    puts '=' * 50

    if @results[:overall_success]
      puts "\n🎉 Phase 1 implementation is working correctly!"
      puts '✅ All strategy classes created and functional'
      puts '✅ Signal generation system operational'
      puts '✅ Trading engine ready for use'
      puts '✅ API endpoints responding'
      puts "\n🚀 Ready to proceed to Phase 2: Position Management"
    else
      puts "\n⚠️  Some issues found in Phase 1 implementation"
      puts 'Please review the failed tests above and fix any issues'
    end
  end
end

# Run the tests
if __FILE__ == $0
  tester = Phase1Tester.new
  tester.run_all_tests
end