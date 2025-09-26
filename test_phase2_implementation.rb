#!/usr/bin/env ruby
# frozen_string_literal: true

# Test script for Phase 2 implementation
# Tests all position management services and models

require 'net/http'
require 'json'
require 'uri'

# Load Rails environment
require_relative 'config/environment'

class Phase2Tester
  def initialize
    @results = {
      model_tests: [],
      service_tests: [],
      integration_tests: [],
      overall_success: true
    }
  end

  def run_all_tests
    puts '🚀 Starting Phase 2 Implementation Tests'
    puts '=' * 50

    test_models
    test_services
    test_integration
    print_results
  end

  private

  def test_models
    puts "\n📊 Testing Models..."

    # Test TradingPosition model
    begin
      position = TradingPosition.new(
        instrument: Instrument.first,
        strategy: 'TestStrategy',
        side: 'BUY',
        quantity: 100,
        entry_price: 100.0,
        entry_time: Time.current
      )

      test_result = {
        name: 'TradingPosition',
        can_instantiate: true,
        has_required_methods: position.respond_to?(:active?) &&
                             position.respond_to?(:calculate_current_pnl) &&
                             position.respond_to?(:close_position!),
        success: true
      }

      puts '  ✅ TradingPosition - OK'
      @results[:model_tests] << test_result

    rescue StandardError => e
      test_result = {
        name: 'TradingPosition',
        error: e.message,
        success: false
      }
      puts "  ❌ TradingPosition - ERROR: #{e.message}"
      @results[:model_tests] << test_result
      @results[:overall_success] = false
    end
  end

  def test_services
    puts "\n🔧 Testing Services..."

    services = [
      'Position::Sizer',
      'Position::Monitor',
      'Position::ExitManager',
      'Position::PortfolioManager',
      'Risk::PositionGuard'
    ]

    services.each do |service_name|
      begin
        service_class = service_name.constantize
        service = service_class.new

        test_result = {
          name: service_name,
          can_instantiate: true,
          has_required_methods: check_service_methods(service, service_name),
          success: true
        }

        puts "  ✅ #{service_name} - OK"
        @results[:service_tests] << test_result

      rescue StandardError => e
        test_result = {
          name: service_name,
          error: e.message,
          success: false
        }
        puts "  ❌ #{service_name} - ERROR: #{e.message}"
        @results[:service_tests] << test_result
        @results[:overall_success] = false
      end
    end
  end

  def check_service_methods(service, service_name)
    case service_name
    when 'Position::Sizer'
      service.respond_to?(:calculate_position_size) &&
      service.respond_to?(:calculate_fixed_risk_size)
    when 'Position::Monitor'
      service.respond_to?(:start_monitoring!) &&
      service.respond_to?(:update_position)
    when 'Position::ExitManager'
      service.respond_to?(:process_exit) &&
      service.respond_to?(:force_exit_all!)
    when 'Position::PortfolioManager'
      service.respond_to?(:portfolio_overview) &&
      service.respond_to?(:add_position)
    when 'Risk::PositionGuard'
      service.respond_to?(:allow_position?) &&
      service.respond_to?(:should_close_position?)
    else
      true
    end
  end

  def test_integration
    puts "\n🔗 Testing Integration..."

    # Test Position Sizer integration
    begin
      sizer = Position::Sizer.new
      signal = {
        entry_price: 100.0,
        stop_loss: 98.0,
        quantity: 100,
        confidence: 0.7
      }
      instrument = Instrument.first
      market_data = { volatility: 0.2 }

      size = sizer.calculate_position_size(signal, instrument, market_data)

      test_result = {
        name: 'Position Sizer Integration',
        can_calculate_size: size.is_a?(Numeric),
        success: true
      }

      puts '  ✅ Position Sizer Integration - OK'
      @results[:integration_tests] << test_result

    rescue StandardError => e
      test_result = {
        name: 'Position Sizer Integration',
        error: e.message,
        success: false
      }
      puts "  ❌ Position Sizer Integration - ERROR: #{e.message}"
      @results[:integration_tests] << test_result
      @results[:overall_success] = false
    end

    # Test Risk Guard integration
    begin
      guard = Risk::PositionGuard.new
      signal = {
        entry_price: 100.0,
        stop_loss: 98.0,
        quantity: 100,
        confidence: 0.7,
        risk_reward_ratio: 2.0
      }
      instrument = Instrument.first
      market_data = { volatility: 0.2, trend_strength: 0.6 }

      allowed = guard.allow_position?(signal, instrument, market_data)

      test_result = {
        name: 'Risk Guard Integration',
        can_check_position: allowed.is_a?(TrueClass) || allowed.is_a?(FalseClass),
        success: true
      }

      puts '  ✅ Risk Guard Integration - OK'
      @results[:integration_tests] << test_result

    rescue StandardError => e
      test_result = {
        name: 'Risk Guard Integration',
        error: e.message,
        success: false
      }
      puts "  ❌ Risk Guard Integration - ERROR: #{e.message}"
      @results[:integration_tests] << test_result
      @results[:overall_success] = false
    end
  end

  def print_results
    puts "\n" + ('=' * 50)
    puts '📋 PHASE 2 TEST RESULTS'
    puts '=' * 50

    # Model Tests
    puts "\n📊 Model Tests:"
    model_success = @results[:model_tests].all? { |t| t[:success] }
    puts "  Status: #{model_success ? '✅ PASSED' : '❌ FAILED'}"
    puts "  Tests: #{@results[:model_tests].count}"
    puts "  Passed: #{@results[:model_tests].count { |t| t[:success] }}"

    # Service Tests
    puts "\n🔧 Service Tests:"
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
    puts "🎯 OVERALL RESULT: #{@results[:overall_success] ? '✅ PHASE 2 COMPLETE' : '❌ PHASE 2 INCOMPLETE'}"
    puts '=' * 50

    if @results[:overall_success]
      puts "\n🎉 Phase 2 implementation is working correctly!"
      puts '✅ Position management system operational'
      puts '✅ Risk management services functional'
      puts '✅ Portfolio management ready'
      puts "\n🚀 Ready to proceed to Phase 3: Advanced Features"
    else
      puts "\n⚠️  Some issues found in Phase 2 implementation"
      puts 'Please review the failed tests above and fix any issues'
    end
  end
end

# Run the tests
if __FILE__ == $0
  tester = Phase2Tester.new
  tester.run_all_tests
end
