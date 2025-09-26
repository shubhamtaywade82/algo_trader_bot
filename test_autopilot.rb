#!/usr/bin/env ruby
# Test script for Autopilot integration

require 'net/http'
require 'json'
require 'uri'

class AutopilotTester
  def initialize
    @base_url = 'http://localhost:3000'
    @api_key = ENV['LLM_API_KEY'] || 'admin_key'
  end

  def test_agent_health
    puts "\n=== Testing Agent Health ==="
    response = make_request('GET', '/autopilot/agent_health')
    puts "Status: #{response[:status]}"
    puts "Response: #{JSON.pretty_generate(response[:data])}"
  end

  def test_autopilot_status
    puts "\n=== Testing Autopilot Status ==="
    response = make_request('GET', '/autopilot/status')
    puts "Status: #{response[:status]}"
    puts "Response: #{JSON.pretty_generate(response[:data])}"
  end

  def test_send_signal
    puts "\n=== Testing Signal Processing ==="

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

    response = make_request('POST', '/autopilot/signal', signal_data)
    puts "Status: #{response[:status]}"
    puts "Response: #{JSON.pretty_generate(response[:data])}"
  end

  def test_start_autopilot
    puts "\n=== Testing Autopilot Start ==="
    response = make_request('POST', '/autopilot/start')
    puts "Status: #{response[:status]}"
    puts "Response: #{JSON.pretty_generate(response[:data])}"
  end

  def test_stop_autopilot
    puts "\n=== Testing Autopilot Stop ==="
    response = make_request('POST', '/autopilot/stop')
    puts "Status: #{response[:status]}"
    puts "Response: #{JSON.pretty_generate(response[:data])}"
  end

  def run_all_tests
    puts 'Autopilot Integration Tester'
    puts '============================'
    puts "Rails URL: #{@base_url}"
    puts "API Key: #{@api_key}"

    test_agent_health
    test_autopilot_status
    test_start_autopilot
    test_send_signal
    test_autopilot_status
    test_stop_autopilot

    puts "\n=== All tests completed ==="
  end

  private

  def make_request(method, path, body = nil)
    uri = URI("#{@base_url}#{path}")

    case method.upcase
    when 'GET'
      request = Net::HTTP::Get.new(uri)
    when 'POST'
      request = Net::HTTP::Post.new(uri)
      request['Content-Type'] = 'application/json'
      request.body = body.to_json if body
    end

    request['X-API-KEY'] = @api_key

    response = Net::HTTP.start(uri.hostname, uri.port) do |http|
      http.request(request)
    end

    data = JSON.parse(response.body, symbolize_names: true)
    { status: response.code.to_i, data: data }
  rescue StandardError => e
    puts "Error: #{e.message}"
    { status: 500, data: { error: e.message } }
  end
end

# Run tests
if __FILE__ == $PROGRAM_NAME
  puts 'Make sure to:'
  puts '1. Set AGENT_URL in .env file'
  puts '2. Start Rails server: rails server'
  puts '3. Ensure your LLM agent is running on the AGENT_URL'
  puts ''

  tester = AutopilotTester.new
  tester.run_all_tests
end
