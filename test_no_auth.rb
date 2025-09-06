#!/usr/bin/env ruby
# Test script for Rails API without authentication

require 'net/http'
require 'json'
require 'uri'

class NoAuthTester
  def initialize
    @base_url = 'http://localhost:3000'
  end

  def test_all_endpoints
    puts 'Testing Rails API with Live DhanHQ Data'
    puts '======================================='
    puts "Rails URL: #{@base_url}"
    puts 'Authentication: None (local use only)'
    puts 'Data Source: Live DhanHQ APIs'
    puts ''

    # Test LLM endpoints
    puts '=== LLM Endpoints (Live Data) ==='
    test_endpoint('GET', '/llm/funds', 'Funds')
    test_endpoint('GET', '/llm/positions', 'Positions')
    test_endpoint('GET', '/llm/orders', 'Orders')
    test_endpoint('GET', '/llm/spot?underlying=NIFTY', 'Spot Price')
    test_endpoint('GET', '/llm/quote?securityId=256265', 'Quote')
    test_endpoint('GET', '/llm/option_chain?underlying=NIFTY&expiry=2024-01-25', 'Option Chain')

    # Test order placement (paper mode)
    test_endpoint('POST', '/llm/place_bracket_order', 'Place Order', {
                    securityId: 256_265,
                    qty: 1,
                    sl_pct: 1.0,
                    tp_pct: 1.0
                  })

    # Test autopilot endpoints
    puts "\n=== Autopilot Endpoints ==="
    test_endpoint('GET', '/autopilot/agent_health', 'Agent Health')
    test_endpoint('GET', '/autopilot/status', 'Autopilot Status')

    puts "\n=== All tests completed ==="
  end

  def test_endpoint(method, path, description, body = nil)
    uri = URI("#{@base_url}#{path}")

    case method.upcase
    when 'GET'
      request = Net::HTTP::Get.new(uri)
    when 'POST'
      request = Net::HTTP::Post.new(uri)
      request['Content-Type'] = 'application/json'
      request.body = body.to_json if body
    end

    # No authentication headers needed

    begin
      response = Net::HTTP.start(uri.hostname, uri.port) do |http|
        http.request(request)
      end

      puts "\n--- #{description} (#{method} #{path}) ---"
      puts "Status: #{response.code}"

      if response.code.to_i == 200
        begin
          data = JSON.parse(response.body, symbolize_names: true)
          puts "✅ Success: #{JSON.pretty_generate(data)}"
        rescue JSON::ParserError
          puts "✅ Success: #{response.body}"
        end
      else
        puts "❌ Error: #{response.body}"
      end
    rescue StandardError => e
      puts "\n--- #{description} (#{method} #{path}) ---"
      puts "❌ Connection Error: #{e.message}"
    end
  end
end

# Run tests
if __FILE__ == $PROGRAM_NAME
  puts 'Make sure to:'
  puts '1. Start Rails server: rails server'
  puts '2. Set DHAN_CLIENT_ID and DHAN_ACCESS_TOKEN in .env'
  puts '3. No authentication required for API calls'
  puts '4. This test uses LIVE DhanHQ data'
  puts ''

  tester = NoAuthTester.new
  tester.test_all_endpoints
end
