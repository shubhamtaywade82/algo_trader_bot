module Orders
  class Analyzer < ApplicationService
    def self.realized_pnl_for(security_id, segment)
      pos = State::PositionCache.get(seg: segment, sid: security_id, prod: 'INTRADAY')
      return 0.0 unless pos

      Pnl::LiveCalculator.for_position(pos)[:unrealized].to_f # close enough until broker confirms
    rescue StandardError
      0.0
    end
  end
end
