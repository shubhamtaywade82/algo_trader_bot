# frozen_string_literal: true

module Scalpers
  module Options
    class Runner
      def initialize(infra:, watchlist:, policy: nil, sizer: nil, executor: nil, logger: Rails.logger, **opts)
        @infra = infra
        chain_picker = ChainPicker.new(logger: logger)
        @policy = policy || Policy.new(chain_picker: chain_picker, logger: logger)
        @sizer = sizer || Sizer.new(base_sizing: infra.sizing, logger: logger)
        @executor = executor || Executor.new(logger: logger)
        @base_runner = Scalpers::Base::Runner.new(
          infra: infra,
          policy: @policy,
          sizer: @sizer,
          executor: @executor,
          watchlist: watchlist,
          logger: logger,
          **opts
        )
      end

      def start!
        @base_runner.start!
      end

      def stop!
        @base_runner.stop!
      end

      def run_once(now: Time.zone.now)
        @base_runner.run_once(now: now)
      end
    end
  end
end
