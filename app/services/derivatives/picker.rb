# frozen_string_literal: true

# app/services/derivatives/picker.rb
#
# Orchestrates "what to trade" for AutoPilot:
#  - fetch nearest-expiry option chain for an underlying
#  - compute iv_rank (0..1) for current chain
#  - call Option::ChainAnalyzer (your advanced scorer) to gate & rank strikes
#  - resolve the chosen strike into a tradable Derivative (security_id, lot_size)
#
# Returns Result struct or nil.
#
# Usage:
#   pick = Derivatives::Picker.call(
#     instrument: nifty,                # AR Instrument
#     side: :ce,                        # :ce or :pe (bullish=ce / bearish=pe)
#     strategy_type: 'intraday',        # 'intraday' or 'swing'
#     expiry: nil,                      # default nearest expiry
#     signal_strength: 1.0              # optional multiplier into analyzer
#   )
#   if pick
#     pick.derivative   # => AR Derivative (has security_id, lot_size)
#     pick.selected     # => Hash from analyzer (strike_price, last_price, iv, greeks…)
#     pick.ranked       # => Top-N ranked array from analyzer
#     pick.side         # => :ce / :pe
#     pick.expiry       # => Date
#   end
#
module Derivatives
  class Picker < ApplicationService
    Result = Struct.new(:selected, :ranked, :derivative, :expiry, :side, :iv_rank, keyword_init: true)

    def initialize(instrument:, side:, strategy_type: 'intraday', expiry: nil, signal_strength: 1.0)
      @instrument      = instrument
      @side            = side.to_s.downcase.to_sym # :ce or :pe
      @strategy_type   = strategy_type.to_s
      @signal_strength = signal_strength.to_f
      @expiry          = expiry || safe_nearest_expiry_for(instrument)
    end

    def call
      return nil unless @instrument && %i[ce pe].include?(@side) && @expiry

      chain = fetch_chain(@expiry)
      return nil unless chain && chain[:oc].present?

      iv_rank = iv_rank_for(chain)

      analyzer = Option::ChainAnalyzer.new(
        chain,
        expiry: @expiry,
        underlying_spot: (chain[:last_price].presence || ltp(@instrument)).to_f,
        iv_rank: iv_rank,
        historical_data: @instrument.intraday_ohlc(interval: '5', days: 3) || historical_data
      )
      res = analyzer.analyze(signal_type: @side, strategy_type: @strategy_type, signal_strength: @signal_strength)
      return nil unless res[:proceed] && res[:selected]

      drv = resolve_derivative(res[:selected], @expiry, @side)
      return nil unless drv

      Result.new(
        selected: res[:selected],
        ranked: res[:ranked],
        derivative: drv,
        expiry: @expiry,
        side: @side,
        iv_rank: iv_rank
      )
    rescue StandardError => e
      Rails.logger.error("[Derivatives::Picker] #{e.class} – #{e.message}")
      nil
    end

    # ------------------------------------------------------------------------
    private

    def fetch_chain(expiry)
      @instrument.fetch_option_chain(expiry)
    rescue StandardError => e
      Rails.logger.error("[Derivatives::Picker] chain fetch failed for #{expiry}: #{e.message}")
      nil
    end

    def safe_nearest_expiry_for(inst)
      list = Array(inst.expiry_list)
      list.first if list.any?
    rescue StandardError
      nil
    end

    def ltp(inst)
      Live::TickCache.ltp(inst.exchange_segment, inst.security_id) || inst.ltp
    rescue StandardError
      nil
    end

    # Normalizes current IV within chain range → rank ∈ [0,1].
    def iv_rank_for(chain)
      oc = chain[:oc] || {}
      spot = (chain[:last_price] || 0).to_f
      return 0.5 if oc.empty? || spot <= 0

      strikes = oc.keys.map(&:to_f)
      atm     = strikes.min_by { |s| (s - spot).abs }
      return 0.5 unless atm

      atm_k = format('%.6f', atm)
      ce_iv = oc.dig(atm_k, 'ce', 'implied_volatility').to_f
      pe_iv = oc.dig(atm_k, 'pe', 'implied_volatility').to_f
      current = [ce_iv, pe_iv].select(&:positive?).then { |a| a.empty? ? 0 : a.sum / a.size }

      all = oc.values.flat_map { |row| %w[ce pe].map { |k| row.dig(k, 'implied_volatility').to_f } }.reject(&:zero?)
      return 0.5 if all.empty? || all.max == all.min

      ((current - all.min) / (all.max - all.min)).clamp(0.0, 1.0).round(3)
    rescue StandardError
      0.5
    end

    def historical_data
      if @strategy_type == 'intraday'
        intraday_candles
      else
        daily_candles
      end
    end

    def daily_candles
      DhanHQ::Models::HistoricalData.daily(
        securityId: @instrument.security_id,
        exchangeSegment: @instrument.exchange_segment,
        instrument: @instrument.instrument_type,
        fromDate: 45.days.ago.to_date,
        toDate: Date.yesterday
      )
    rescue StandardError
      []
    end

    def intraday_candles
      DhanHQ::Models::HistoricalData.intraday(
        security_id: @instrument.security_id,
        exchange_segment: @instrument.exchange_segment,
        instrument: @instrument.instrument_type,
        interval: '5',
        from_date: 5.days.ago.to_date.iso8601,
        to_date: Time.zone.today.iso8601
      )
    rescue StandardError
      []
    end

    def resolve_derivative(selected, expiry, side)
      @instrument.derivatives.find_by(
        strike_price: selected[:strike_price],
        expiry_date: expiry,
        option_type: side.to_s.upcase # 'CE' / 'PE'
      )
    rescue StandardError => e
      Rails.logger.error("[Derivatives::Picker] derivative lookup failed: #{e.message}")
      nil
    end
  end
end
