# frozen_string_literal: true

module Options
  # Facade for legacy callers. Picks ATM± range via Option::ChainAnalyzer and
  # returns a single best row with derivative details (security_id, lot_size, …)
  class ChainAnalyzer < ApplicationService
    def initialize(underlying:, side:, config: {})
      @ul     = underlying
      @side   = side.to_s.downcase.to_sym # :ce / :pe
      @config = {
        strategy_type: 'intraday'
      }.merge(config || {})
    end

    def call
      expiry = nearest_expiry(@ul)
      return nil unless expiry

      chain = safe_fetch_option_chain(@ul, expiry)
      return nil if chain.blank? || chain[:oc].blank?

      iv_rank = compute_iv_rank(chain)
      spot    = chain[:last_price].to_f.nonzero? || @ul.ws_ltp || @ul.ltp
      hist    = intraday_candles(@ul)

      # Use the advanced analyzer
      analyzer = Option::ChainAnalyzer.new(
        chain,
        expiry: expiry,
        underlying_spot: spot.to_f,
        iv_rank: iv_rank,
        historical_data: hist
      )

      result = analyzer.analyze(signal_type: @side, strategy_type: @config[:strategy_type])

      return nil unless result[:proceed] && (sel = result[:selected])

      # Enrich with derivative info (security_id, lot, segment) and bid/ask
      leg = to_legacy_row(@ul, chain, sel, expiry, @side)
      return nil unless leg

      # Final light guard (keeps your old expectations: non‑zero price, etc.)
      return nil if leg[:ltp].to_f <= 0

      leg
    rescue StandardError => e
      Rails.logger.error("[Options::ChainAnalyzer] #{e.class} #{e.message}")
      nil
    end

    private

    def nearest_expiry(inst)
      Array(inst.expiry_list).first
    rescue StandardError
      nil
    end

    def safe_fetch_option_chain(inst, expiry)
      inst.fetch_option_chain(expiry)
    rescue StandardError => e
      Rails.logger.error("[Options::ChainAnalyzer] option-chain fetch failed (#{expiry}): #{e.message}")
      nil
    end

    # Same formula you used inside AlertProcessors::Index#iv_rank_for
    def compute_iv_rank(chain)
      atm = determine_atm_strike(chain)
      return 0.5 unless atm

      key   = format('%.6f', atm)
      ce_iv = chain[:oc].dig(key, 'ce', 'implied_volatility').to_f
      pe_iv = chain[:oc].dig(key, 'pe', 'implied_volatility').to_f
      cur   = [ce_iv, pe_iv].select(&:positive?).then { |arr| arr.empty? ? 0.0 : (arr.sum / arr.size) }

      ivs = chain[:oc].values.flat_map { |row| %w[ce pe].map { |k| row.dig(k, 'implied_volatility').to_f } }.reject(&:zero?)
      return 0.5 if ivs.empty? || ivs.max == ivs.min

      ((cur - ivs.min) / (ivs.max - ivs.min)).clamp(0, 1).round(2)
    rescue StandardError
      0.5
    end

    def determine_atm_strike(chain)
      spot = chain[:last_price].to_f
      chain[:oc].keys.map(&:to_f).min_by { |s| (s - spot).abs }
    rescue StandardError
      nil
    end

    def intraday_candles(inst)
      DhanHQ::Models::HistoricalData.intraday(
        security_id: inst.security_id,
        exchange_segment: inst.exchange_segment,
        instrument: inst.instrument_type,
        interval: '5',
        from_date: 5.days.ago.to_date.to_s,
        to_date: Time.zone.today.to_s
      )
    rescue StandardError
      []
    end

    def to_legacy_row(inst, chain, sel, expiry, side)
      strike_f = sel[:strike_price].to_f
      strike_key = format('%.6f', strike_f)
      side_s     = side.to_s

      node       = chain[:oc][strike_key]
      side_node  = node && node[side_s]
      return nil unless side_node

      # Map to DB derivative
      derivative = inst.derivatives.find_by(
        strike_price: strike_f,
        expiry_date: expiry,
        option_type: side.to_s.upcase
      )
      return nil unless derivative

      bid = side_node['top_bid_price'].to_f
      ask = side_node['top_ask_price'].to_f
      mid = [(bid + ask) / 2.0, sel[:last_price].to_f].compact.max
      spread = ask.positive? && bid.positive? ? (ask - bid).abs : nil
      spread_pct = mid.positive? && spread ? ((spread / mid) * 100.0) : nil

      {
        # legacy shape expected by Strategy loop
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
