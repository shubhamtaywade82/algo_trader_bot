# frozen_string_literal: true

module Option
  class ChainAnalyzer
    IV_RANK_MIN        = 0.00
    IV_RANK_MAX        = 0.80
    THETA_AVOID_HOUR   = 14.5 # 2:30 PM
    TOP_RANKED_LIMIT   = 10

    attr_reader :option_chain, :expiry, :underlying_spot, :historical_data, :iv_rank, :ta

    def initialize(option_chain, expiry:, underlying_spot:, iv_rank:, historical_data: [])
      @option_chain     = option_chain.with_indifferent_access
      @expiry           = Date.parse(expiry.to_s)
      @underlying_spot  = underlying_spot.to_f
      @iv_rank          = iv_rank.to_f
      @historical_data  = historical_data || []
      @ta = (Indicators::HolyGrail.call(candles: historical_data) if historical_data.present?)

      Rails.logger.debug { "[Option::ChainAnalyzer] Analyzing Options for #{expiry}" }
      raise ArgumentError, 'Option Chain is missing or empty!' if @option_chain[:oc].blank?
    end

    # Main entry
    def analyze(signal_type:, strategy_type:, signal_strength: 1.0)
      result = {
        proceed: true,
        reason: nil,
        signal_type: signal_type, # :ce / :pe
        trend: nil,
        momentum: nil,
        adx: nil,
        selected: nil,
        ranked: [],
        ta_snapshot: ta ? ta.to_h : {}
      }

      # 1) Core sanity gates
      if iv_rank_outside_range?
        result[:proceed] = false
        result[:reason]  = 'IV rank outside range'
      elsif discourage_late_entry_due_to_theta?
        result[:proceed] = false
        result[:reason]  = 'Late entry, theta risk'
      end

      # 2) Bias / momentum / ADX (HolyGrail if available)
      result[:trend]    = ta ? ta.bias.to_sym     : intraday_trend
      result[:momentum] = ta ? ta.momentum.to_sym : :flat
      result[:adx]      = ta&.adx
      adx_ok            = ta ? ta.adx.to_f >= 25 : true

      if result[:proceed] && !(trend_confirms?(result[:trend], signal_type) && adx_ok && result[:momentum] != :flat)
        result[:proceed] = false
        result[:reason]  = 'trend/momentum filter'
      end

      # 3) Candidate strikes → score → rank
      if result[:proceed]
        filtered = gather_filtered_strikes(signal_type)
        if filtered.empty?
          result[:proceed] = false
          result[:reason]  = 'No tradable strikes found'
        else
          m_boost = (result[:momentum] == :strong ? 1.15 : 1.0)
          ranked  = filtered.map do |opt|
            score = score_for(opt, strategy_type, signal_type, signal_strength) * m_boost
            opt.merge(score: score)
          end.sort_by { |o| -o[:score] }

          result[:ranked]   = ranked.first(TOP_RANKED_LIMIT)
          result[:selected] = result[:ranked].first
        end
      end

      result
    end

    # Public helper
    def current_trend = intraday_trend
    alias trend current_trend

    private

    def iv_rank_outside_range?
      @iv_rank < IV_RANK_MIN || @iv_rank > IV_RANK_MAX
    end

    def gather_filtered_strikes(signal_type)
      side = signal_type.to_sym # :ce / :pe

      @option_chain[:oc].filter_map do |strike_str, row|
        opt = row[side.to_s]
        next unless opt

        # Must have price + IV
        next if opt['implied_volatility'].to_f.zero? || opt['last_price'].to_f.zero?

        strike_price = strike_str.to_f
        delta_abs    = opt.dig('greeks', 'delta').to_f.abs

        # Min Δ gates (time‑of‑day)
        next if delta_abs < min_delta_now

        # Adaptive ATM window
        next unless within_atm_range?(strike_price)

        build_strike_data(strike_price, opt)
      end
    end

    # Dynamic Δ thresholds
    def min_delta_now
      h = Time.zone.now.hour
      return 0.45 if h >= 14
      return 0.35 if h >= 13
      return 0.30 if h >= 11

      0.25
    end

    # Adaptive ATM window by IV rank
    def atm_range_pct
      case iv_rank
      when 0.0..0.2 then 0.01
      when 0.2..0.5 then 0.015
      else               0.025
      end
    end

    def within_atm_range?(strike)
      band = atm_range_pct
      lo   = @underlying_spot * (1 - band)
      hi   = @underlying_spot * (1 + band)
      strike.between?(lo, hi)
    end

    def build_strike_data(strike_price, opt)
      {
        strike_price: strike_price,
        last_price: opt['last_price'].to_f,
        iv: opt['implied_volatility'].to_f,
        oi: opt['oi'].to_i,
        volume: opt['volume'].to_i,
        greeks: {
          delta: opt.dig('greeks', 'delta').to_f,
          gamma: opt.dig('greeks', 'gamma').to_f,
          theta: opt.dig('greeks', 'theta').to_f,
          vega: opt.dig('greeks', 'vega').to_f
        },
        previous_close_price: opt['previous_close_price'].to_f,
        previous_oi: opt['previous_oi'].to_i,
        previous_volume: opt['previous_volume'].to_i,
        price_change: opt['last_price'].to_f - opt['previous_close_price'].to_f,
        oi_change: opt['oi'].to_i - opt['previous_oi'].to_i,
        volume_change: opt['volume'].to_i - opt['previous_volume'].to_i,
        bid_ask_spread: (opt['top_ask_price'].to_f - opt['top_bid_price'].to_f).abs
      }
    end

    def score_for(opt, strategy, signal_type, signal_strength)
      spread          = opt[:bid_ask_spread] <= 0 ? 0.1 : opt[:bid_ask_spread]
      last_price      = opt[:last_price].to_f
      relative_spread = spread / (last_price.nonzero? || 1.0)

      oi        = [opt[:oi], 1].max
      volume    = [opt[:volume], 1].max
      delta     = opt[:greeks][:delta].abs
      gamma     = opt[:greeks][:gamma]
      theta     = opt[:greeks][:theta]
      vega      = opt[:greeks][:vega]
      price_chg = opt[:price_change]
      oi_chg    = opt[:oi_change]
      vol_chg   = opt[:volume_change]

      # weights: intraday vs swing
      lw, mw, = (strategy.to_s == 'intraday' ? [0.35, 0.35, 0.3] : [0.25, 0.25, 0.5])

      # Liquidity (penalize wide spreads)
      liquidity_score = ((oi * volume) + vol_chg.abs) / (relative_spread.nonzero? || 0.01)

      # Flow/momentum
      momentum_score  = (oi_chg / 1000.0)
      momentum_score += price_chg.positive? ? price_chg : price_chg.abs if delta >= 0 && price_chg.positive?

      # Theta pressure ↑ near expiry
      days_left     = (@expiry - Time.zone.today).to_i
      theta_penalty = theta.abs * (days_left < 3 ? 2.0 : 1.0)
      greeks_score  = (delta * 100) + (gamma * 10) + (vega * 2) - (theta_penalty * 3)

      # Price efficiency
      efficiency = last_price.zero? ? 0.0 : (price_chg / last_price)
      efficiency_score = efficiency * 30

      total = (liquidity_score * lw) +
              (momentum_score  * mw) +
              (greeks_score    * theta_weight) +
              efficiency_score

      # Skew checks
      z = local_iv_zscore(opt[:iv], opt[:strike_price])
      total *= 0.90 if z > 1.5

      tilt = skew_tilt
      total *= 1.10 if (signal_type == :ce && tilt == :call) || (signal_type == :pe && tilt == :put)

      # Historical IV sanity
      hist_vol = historical_volatility
      if hist_vol.positive?
        iv_ratio = opt[:iv] / hist_vol
        total *= 0.9 if iv_ratio > 1.5
      end

      total * signal_strength
    end

    def theta_weight
      Time.zone.now.hour >= 13 ? 4.0 : 3.0
    end

    def local_iv_zscore(strike_iv, strike)
      neighbours = @option_chain[:oc].keys.map(&:to_f).select { |s| (s - strike).abs <= 300 }
      ivs = neighbours.filter_map do |s|
        node = @option_chain[:oc][format('%.6f', s)]
        (node && node['ce'] && node['ce']['implied_volatility']).to_f
      end
      return 0 if ivs.empty?

      mean = ivs.sum / ivs.size
      var  = ivs.sum { |v| (v - mean)**2 } / ivs.size
      std  = Math.sqrt(var)
      std.zero? ? 0 : (strike_iv - mean) / std
    end

    def skew_tilt
      ce_ivs = collect_side_ivs(:ce)
      pe_ivs = collect_side_ivs(:pe)
      avg_ce = ce_ivs.any? ? ce_ivs.sum / ce_ivs.size.to_f : nil
      avg_pe = pe_ivs.any? ? pe_ivs.sum / pe_ivs.size.to_f : nil

      return :call if avg_ce && avg_pe && avg_ce > avg_pe * 1.1
      return :put  if avg_pe && avg_ce && avg_pe > avg_ce * 1.1

      :neutral
    end

    def collect_side_ivs(side)
      @option_chain[:oc].values.filter_map do |row|
        v = row.dig(side.to_s, 'implied_volatility')
        v.to_f if v && v.to_f > 0
      end
    end

    # simple HV (annualized %)
    def historical_volatility
      return 0 if @historical_data.blank?

      closes = @historical_data['close'] || []
      return 0 if closes.size < 10

      rets = []
      closes.each_cons(2) do |a, b|
        rets << Math.log(b.to_f / a.to_f)
      rescue StandardError
        rets << 0
      end
      mean = rets.sum / (rets.size.nonzero? || 1)
      var  = rets.sum { |r| (r - mean)**2 } / (rets.size.nonzero? || 1)
      Math.sqrt(var) * Math.sqrt(252) * 100.0
    end

    # Flow bias from CE vs PE change around ATM
    def intraday_trend
      atm = determine_atm_strike
      return :neutral unless atm

      window  = 3
      sums    = { ce: 0.0, pe: 0.0 }
      strikes = @option_chain[:oc].keys.map(&:to_f)
      strikes.select { |s| (s - atm).abs <= (window * 100) }.each do |s|
        key = format('%.6f', s)
        %i[ce pe].each do |side|
          opt = @option_chain[:oc].dig(key, side.to_s)
          next unless opt

          change = opt['last_price'].to_f - opt['previous_close_price'].to_f
          sums[side] += change
        end
      end
      diff = sums[:ce] - sums[:pe]
      return :bullish if diff.positive?
      return :bearish if diff.negative?

      :neutral
    end

    def trend_confirms?(trend, signal_type)
      return true if trend == :neutral

      (trend == :bullish && signal_type == :ce) || (trend == :bearish && signal_type == :pe)
    end

    def discourage_late_entry_due_to_theta?
      now           = Time.zone.now
      expiry_today  = (@expiry == now.to_date)
      current_hours = now.hour + (now.min / 60.0)
      expiry_today && current_hours > THETA_AVOID_HOUR
    end

    def determine_atm_strike
      strikes = @option_chain[:oc].keys.map(&:to_f)
      return nil if strikes.empty?

      strikes.min_by { |s| (s - @underlying_spot).abs }
    end
  end
end
