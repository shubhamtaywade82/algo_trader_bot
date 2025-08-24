# frozen_string_literal: true
module Options
  class CloseStrikesManager < ApplicationService
    def initialize(instrument:, side:)
      @instrument = instrument
      @side = side.to_s.upcase
    end

    def call
      pos = Dhanhq::API::Portfolio.positions rescue []
      u_root = @instrument.underlying_symbol.to_s

      to_close = Array(pos).select do |p|
        ts = p['tradingSymbol'].to_s.upcase
        p['positionType'] == 'LONG' &&
          ts.include?(u_root.upcase) &&
          ts.end_with?(@side)
      end

      to_close.each do |p|
        Dhanhq::API::Orders.place(
          transactionType: 'SELL',
          orderType: 'MARKET',
          productType: Dhanhq::Constants::MARGIN,
          validity: Dhanhq::Constants::DAY,
          securityId: p['securityId'],
          exchangeSegment: p['exchangeSegment'],
          quantity: p['quantity']
        )
      end

      to_close.size
    rescue => e
      Rails.logger.error("[Options::CloseStrikesManager] #{e.class} #{e.message}")
      0
    end
  end
end
