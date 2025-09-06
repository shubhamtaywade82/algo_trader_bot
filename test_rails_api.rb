#!/usr/bin/env ruby
# Test script for Rails API (LLM endpoints + Autopilot)

require 'net/http'
require 'json'
require 'uri'

class RailsApiTester
  def initialize
    @base_url = 'http://localhost:3000'
  end

  def test_llm_endpoints
    puts "\n=== Testing LLM API Endpoints ==="

    # Test funds
    test_endpoint('GET', '/llm/funds')

    # Test positions
    test_endpoint('GET', '/llm/positions')

    # Test orders
    test_endpoint('GET', '/llm/orders')

    # Test spot
    test_endpoint('GET', '/llm/spot?underlying=NIFTY')

    # Test quote
    test_endpoint('GET', '/llm/quote?securityId=256265')

    # Test option chain
    test_endpoint('GET', '/llm/option_chain?underlying=NIFTY&expiry=2024-01-25')

    # Test place bracket order (paper mode)
    test_endpoint('POST', '/llm/place_bracket_order', {
                    securityId: 256_265,
                    qty: 1,
                    sl_pct: 1.0,
                    tp_pct: 1.0
                  })
  end

  def test_autopilot_endpoints
    puts "\n=== Testing Autopilot Endpoints ==="

    # Test agent health
    test_endpoint('GET', '/autopilot/agent_health')

    # Test autopilot status
    test_endpoint('GET', '/autopilot/status')

    # Test start autopilot
    test_endpoint('POST', '/autopilot/start')

    # Test send signal
    signal_data = {
      signal: {
        symbol: 'NIFTY',
        spot: 22_490,
        supertrend_15m: 'bullish',
        adx_15m: 32,
        iv_percentile: 65,
        session_time: Time.zone.now.strftime('%H:%M')
      }
    }
    test_endpoint('POST', '/autopilot/signal', signal_data)

    # Test autopilot status again
    test_endpoint('GET', '/autopilot/status')

    # Test stop autopilot
    test_endpoint('POST', '/autopilot/stop')
  end

  def test_endpoint(method, path, body = nil)
    uri = URI("#{@base_url}#{path}")

    case method.upcase
    when 'GET'
      request = Net::HTTP::Get.new(uri)
    when 'POST'
      request = Net::HTTP::Post.new(uri)
      request['Content-Type'] = 'application/json'
      request.body = body.to_json if body
    end

    # No authentication required for local use

    response = Net::HTTP.start(uri.hostname, uri.port) do |http|
      http.request(request)
    end

    puts "\n--- #{method} #{path} ---"
    puts "Status: #{response.code}"

    begin
      data = JSON.parse(response.body, symbolize_names: true)
      puts "Response: #{JSON.pretty_generate(data)}"
    rescue JSON::ParserError
      puts "Response: #{response.body}"
    end

    { status: response.code.to_i, data: response.body }
  rescue StandardError => e
    puts "Error: #{e.message}"
    { status: 500, error: e.message }
  end

  def run_all_tests
    puts 'Rails API Tester (Live DhanHQ Data)'
    puts '==================================='
    puts "Rails URL: #{@base_url}"
    puts 'Authentication: None (local use)'
    puts 'Data Source: Live DhanHQ APIs'
    puts ''

    test_llm_endpoints
    test_autopilot_endpoints

    puts "\n=== All tests completed ==="
  end
end

# Run tests
if __FILE__ == $PROGRAM_NAME
  puts 'Make sure to:'
  puts '1. Start Rails server: rails server'
  puts '2. Set DHAN_CLIENT_ID and DHAN_ACCESS_TOKEN in .env'
  puts '3. Set AGENT_URL in .env file'
  puts '4. Ensure your LLM agent is running on the AGENT_URL'
  puts '5. This test uses LIVE DhanHQ data'
  puts ''

  tester = RailsApiTester.new
  tester.run_all_tests
end
