# frozen_string_literal: true

module Options
  # Backcompat facade: delegates selection to Derivatives::Picker (which uses
  # Option::ChainAnalyzer under the hood) and returns the old "legacy row" hash.
  class ChainAnalyzer < ApplicationService
    def initialize(underlying:, side:, config: {})
      @ul     = underlying
      @side   = side.to_s.downcase.to_sym # :ce / :pe
      @config = { strategy_type: 'intraday' }.merge(config || {})
    end

    def call
      pick = Derivatives::Picker.call(
        instrument: @ul,
        side: @side,
        strategy_type: @config[:strategy_type]
      )
      return nil unless pick&.selected && pick.derivative

      # Re-fetch chain for the chosen expiry to extract bid/ask exactly like before
      chain = safe_fetch_option_chain(@ul, pick.expiry)
      return nil if chain.blank? || chain[:oc].blank?

      leg = to_legacy_row(@ul, chain, pick.selected, pick.expiry, pick.side)
      return nil unless leg && leg[:ltp].to_f.positive?

      leg
    rescue StandardError => e
      Rails.logger.error("[Options::ChainAnalyzer] #{e.class} #{e.message}")
      nil
    end

    private

    def safe_fetch_option_chain(inst, expiry)
      inst.fetch_option_chain(expiry)
    rescue StandardError => e
      Rails.logger.error("[Options::ChainAnalyzer] option-chain fetch failed (#{expiry}): #{e.message}")
      nil
    end

    # unchanged: exactly your previous mapper, so legacy consumers get the same shape/fields
    def to_legacy_row(inst, chain, sel, expiry, side)
      strike_f = sel[:strike_price].to_f
      strike_key = format('%.6f', strike_f)
      side_s     = side.to_s

      node      = chain[:oc][strike_key]
      side_node = node && node[side_s]
      return nil unless side_node

      derivative = inst.derivatives.find_by(
        strike_price: strike_f,
        expiry_date: expiry,
        option_type: side.to_s.upcase
      )
      return nil unless derivative

      bid     = side_node['top_bid_price'].to_f
      ask     = side_node['top_ask_price'].to_f
      mid     = [(bid + ask) / 2.0, sel[:last_price].to_f].compact.max
      spread  = ask.positive? && bid.positive? ? (ask - bid).abs : nil
      spread_pct = mid.positive? && spread ? ((spread / mid) * 100.0) : nil

      {
        security_id: derivative.security_id,
        symbol: derivative.symbol_name || inst.symbol_name,
        cp: side.to_s.upcase.to_sym, # :CE / :PE
        strike: strike_f,
        ltp: sel[:last_price].to_f,
        bid: bid,
        ask: ask,
        spread_pct: (spread_pct && spread_pct.round(3)) || 999.0,
        volume: sel[:volume].to_i,
        oi: sel[:oi].to_i,
        iv: sel[:iv].to_f,
        lot_size: derivative.lot_size || inst.lot_size,
        exchange_segment: derivative.exchange_segment
      }
    end
  end
end
