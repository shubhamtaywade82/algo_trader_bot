# frozen_string_literal: true

module Derivatives
  # Picks the best tradable derivative (CE/PE) for an index/equity using your Option::ChainAnalyzer.
  # Returns a struct with :selected (strike hash), :ranked (top list), :derivative (AR model) or nil.
  class Picker < ApplicationService
    Result = Struct.new(:selected, :ranked, :derivative, :expiry, :side, keyword_init: true)

    def initialize(instrument:, side:, strategy_type: 'intraday', expiry: nil, signal_strength: 1.0)
      @instrument       = instrument
      @side             = side.to_s.downcase.to_sym # :ce or :pe
      @strategy_type    = strategy_type
      @signal_strength  = signal_strength
      @expiry           = (expiry || instrument.expiry_list.first)
    end

    def call
      chain = safe_fetch_chain(@expiry)
      return nil unless chain && chain[:oc].present?

      iv_rank = iv_rank_for(chain)
      analyzer = Option::ChainAnalyzer.new(
        chain,
        expiry: @expiry,
        underlying_spot: chain[:last_price] || @instrument.ltp,
        iv_rank: iv_rank,
        historical_data: historical_data
      )

      res = analyzer.analyze(signal_type: @side, strategy_type: @strategy_type, signal_strength: @signal_strength)
      return nil unless res[:proceed] && res[:selected]

      drv = fetch_derivative(res[:selected], @expiry, @side)
      return nil unless drv

      Result.new(selected: res[:selected], ranked: res[:ranked], derivative: drv, expiry: @expiry, side: @side)
    rescue => e
      Rails.logger.error("[Derivatives::Picker] #{e.class} #{e.message}")
      nil
    end

    private

    def safe_fetch_chain(expiry)
      @instrument.fetch_option_chain(expiry)
    rescue => e
      Rails.logger.error("[Derivatives::Picker] chain fetch failed: #{e.message}")
      nil
    end

    # Normalize current IV to a 0..1 rank across chain.
    def iv_rank_for(chain)
      spot_iv = begin
        atm_k = format('%.6f', chain[:oc].keys.map(&:to_f).min_by { |s| (s - (chain[:last_price].to_f)).abs })
        ce = chain[:oc].dig(atm_k, 'ce', 'implied_volatility').to_f
        pe = chain[:oc].dig(atm_k, 'pe', 'implied_volatility').to_f
        [ce, pe].select(&:positive?).sum / 2.0
      end

      all = chain[:oc].values.flat_map { |row| %w[ce pe].map { |k| row.dig(k, 'implied_volatility').to_f } }.reject(&:zero?)
      return 0.5 if all.empty? || (all.max == all.min)
      ((spot_iv - all.min) / (all.max - all.min)).clamp(0, 1).round(2)
    rescue
      0.5
    end

    def historical_data
      return intraday_candles if @strategy_type.to_s == 'intraday'
      daily_candles
    end

    def daily_candles
      Dhanhq::API::Historical.daily(
        securityId: @instrument.security_id,
        exchangeSegment: @instrument.exchange_segment,
        instrument: @instrument.instrument_type,
        fromDate: 45.days.ago.to_date,
        toDate: Date.yesterday
      )
    rescue
      []
    end

    def intraday_candles
      Dhanhq::API::Historical.intraday(
        securityId: @instrument.security_id,
        exchangeSegment: @instrument.exchange_segment,
        instrument: @instrument.instrument_type,
        interval: '5',
        fromDate: 5.days.ago.to_date.iso8601,
        toDate: Time.zone.today.iso8601
      )
    rescue
      []
    end

    def fetch_derivative(selected, expiry, side)
      @instrument.derivatives.find_by(
        strike_price: selected[:strike_price],
        expiry_date: expiry,
        option_type: side.to_s.upcase
      )
    end
  end
end
