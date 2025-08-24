# frozen_string_literal: true

module Orders
  class Analyzer < ApplicationService
    # Computes live P&L % for the given super order reference.
    def self.unrealized_pnl_pct(super_ref:)
      order = State::OrderCache.get(super_ref)
      return 0.0 unless order
      seg, sid = order.values_at(:seg, :sid)
      ltp = Live::TickCache.ltp(seg, sid)
      return 0.0 unless ltp
      ep = order[:entry_price].to_f
      return 0.0 if ep <= 0
      (ltp - ep) / ep
    end

    def self.realized_pnl_for(super_ref:)
      order = State::OrderCache.get(super_ref)
      order ? order[:realized_pnl].to_f : 0.0
    end
  end
end
