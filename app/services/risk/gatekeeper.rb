module Risk
  class Gatekeeper
    Decision = Struct.new(:intent, :reason, keyword_init: true)

    def self.evaluate(plan:, facts:)
      return Decision.new(intent: :noop, reason: 'noop') if plan['intent'] == 'noop'
      return Decision.new(intent: :noop, reason: 'cutoff') unless within_entry_window?
      return Decision.new(intent: :noop, reason: 'trades/day cap') if Trades::Counter.limit_reached?
      return Decision.new(intent: :noop, reason: 'daily max loss') if PnL::Limits.daily_loss_breached?

      max_iv = plan.dig('filters', 'max_iv_percentile')
      if max_iv && facts[:iv_percentile].to_f > max_iv.to_f
        return Decision.new(intent: :noop, reason: 'IV%>cap')
      end

      Decision.new(intent: :enter, reason: 'ok')
    end

    def self.within_entry_window?
      cutoff = (ENV['ENTRY_CUTOFF'] || '15:20')
      Time.zone.now.strftime('%H:%M') <= cutoff
    end
  end
end
