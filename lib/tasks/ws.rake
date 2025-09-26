# frozen_string_literal: true

namespace :ws do
  desc 'Check DhanHQ WebSocket connectivity (requires ACCESS_TOKEN & CLIENT_ID env)'
  task :check, %i[segment security_id mode timeout] => :environment do |_t, args|
    require 'timeout'

    segment = args[:segment] || ENV.fetch('WS_CHECK_SEGMENT', 'IDX_I')
    security_id = args[:security_id] || ENV.fetch('WS_CHECK_SECURITY_ID', '13')
    mode = (args[:mode] || ENV.fetch('WS_CHECK_MODE', 'quote')).to_sym
    timeout_seconds = (args[:timeout] || ENV.fetch('WS_CHECK_TIMEOUT', 10)).to_f

    unless DhanHQ.configuration&.access_token && DhanHQ.configuration.client_id
      puts '❌ DhanHQ credentials missing. Set ACCESS_TOKEN and CLIENT_ID before running this task.'
      exit 1
    end

    puts "Connecting to DhanHQ WS (mode=#{mode}, segment=#{segment}, security_id=#{security_id})"

    queue = Queue.new
    client = DhanHQ::WS::Client.new(mode: mode).start
    client.on(:tick) do |tick|
      queue << tick if tick[:security_id].to_s == security_id.to_s
    end
    client.subscribe_one(segment: segment, security_id: security_id)

    tick = Timeout.timeout(timeout_seconds) { queue.pop }

    ts = tick[:ts]
    ts_readable = ts ? Time.zone.at(ts / 1000.0) : Time.zone.now
    puts "✅ Tick received at #{ts_readable}"
    puts "   kind=#{tick[:kind]} ltp=#{tick[:ltp]} segment=#{tick[:segment]} security_id=#{tick[:security_id]}"
    puts 'WebSocket connectivity OK.'
  rescue Timeout::Error
    puts "❌ No tick received within #{timeout_seconds} seconds."
    exit 1
  rescue StandardError => e
    puts "❌ WebSocket check failed: #{e.class}: #{e.message}"
    exit 1
  ensure
    begin
      client&.unsubscribe_one(segment: segment, security_id: security_id)
      client&.disconnect!
    rescue StandardError
      nil
    end
  end
end
