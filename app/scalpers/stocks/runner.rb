# frozen_string_literal: true

module Scalpers
  module Stocks
    class Runner
      def initialize(infra:, watchlist:, policy: nil, sizer: nil, executor: nil, logger: Rails.logger, demo_mode: false, **opts)
        @infra = infra
        @policy = policy || Policy.new(logger: logger)
        @sizer = sizer || Sizer.new(base_sizing: infra.sizing, logger: logger)
        @executor = executor || build_executor(logger: logger, demo_mode: demo_mode)
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

      private

      def build_executor(logger:, demo_mode:)
        return Executor::Demo.new(logger: logger) if demo_mode

        Executor.new(logger: logger)
      end
    end
  end
end
