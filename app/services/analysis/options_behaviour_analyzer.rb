module Analysis
  class OptionsBehaviourAnalyzer < ApplicationService
    def initialize(option_chain:, expiry:, underlying_spot:, symbol:, historical: [])
      @chain = option_chain.with_indifferent_access
      @expiry = expiry
      @spot = underlying_spot
      @symbol = symbol
      @historical = historical
    end

    def call
      atm = determine_atm
      return nil unless atm

      analysis = {
        symbol: @symbol,
        expiry: @expiry,
        spot: @spot,
        atm: atm,
        ce: extract_behaviour_data(atm, :ce),
        pe: extract_behaviour_data(atm, :pe),
        time: Time.zone.now
      }

      notify("🧠 Behaviour Data Prepared for #{@symbol}\n\n#{analysis.inspect.truncate(1200)}", tag: 'OPTIONS_BEHAVIOUR')

      analysis
    end

    private

    def determine_atm
      @chain[:oc].keys.map(&:to_f).min_by { |s| (@spot - s).abs }
    end

    def extract_behaviour_data(strike, side)
      Rails.logger.debug @chain[:oc]
      data = @chain[:oc][format('%.6f', strike)][side.to_s]
      return {} unless data

      {
        last_price: data['last_price'],
        iv: data['implied_volatility'],
        delta: data.dig('greeks', 'delta'),
        gamma: data.dig('greeks', 'gamma'),
        theta: data.dig('greeks', 'theta'),
        vega: data.dig('greeks', 'vega'),
        oi: data['oi'],
        volume: data['volume'],
        price_change: data['last_price'].to_f - data['previous_close_price'].to_f,
        oi_change: data['oi'].to_i - data['previous_oi'].to_i
      }
    end
  end
end