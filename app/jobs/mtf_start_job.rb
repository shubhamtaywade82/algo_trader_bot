# app/jobs/mtf_start_job.rb
class MtfStartJob < ApplicationJob
  queue_as :default
  def perform
    # Live::WsHub.instance.start!(mode: :quote) # already in initializer; idempotent
    Runner::MtfLoop.start(symbols: %w[NIFTY BANKNIFTY], timeframe: '15m')
  end
end
