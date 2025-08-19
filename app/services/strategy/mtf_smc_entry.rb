# frozen_string_literal: true

module Strategy
  class MtfSmcEntry
    Result = Struct.new(:direction, :why, :meta, keyword_init: true) # direction: :bullish/:bearish

    def self.call(instrument)
      s = Mtf::SeriesLoader.load(instrument: instrument, base_interval: '5')
      return nil unless s&.h4 && s.h1 && s.m15

      # 4H: Direction / Key levels / S&D
      bias = case Mtf::Structure.trend(s.h4, lookback: 8)
             when :up   then :bullish
             when :down then :bearish
             else :none
             end

      Rails.logger.debug { "#{instrument.symbol_name}: #{bias}" }
      return nil if bias == :none

      # 1H: Trend + BOS or CHOCH near OB/FVG/liquidity
      h1_trend = Mtf::Structure.trend(s.h1, lookback: 6)
      bos      = Mtf::Structure.bos(s.h1, dir: (bias == :bullish ? :up : :down))
      choch    = Mtf::Structure.choch(s.h1, prior_dir: (bias == :bullish ? :down : :up))
      ob_zone  = Mtf::OrderBlock.last_before_bos(s.h1, bos)
      fvg_list = Mtf::FVG.scan(s.h1, lookback: 40)
      pools    = (bias == :bullish ? Mtf::Liquidity.equal_lows(s.h1) : Mtf::Liquidity.equal_highs(s.h1))

      # Require context alignment: trend or BOS/CHOCH in bias direction
      aligned = (h1_trend == (bias == :bullish ? :up : :down)) || bos || choch
      return nil unless aligned

      # 15m: Confirmation (BOS + pullback to OB/FVG or reaction at liquidity)
      m15_bos = Mtf::Structure.bos(s.m15, dir: (bias == :bullish ? :up : :down))
      return nil unless m15_bos

      last_price = s.m15.candles.last.close
      confirm =
        if ob_zone && Mtf::OrderBlock.price_touches?(ob_zone, last_price)
          :ob_touch
        elsif (gap = fvg_list.last) && Mtf::FVG.price_in_gap?(gap, last_price)
          :fvg_retrace
        elsif (pool = pools.last) && ((bias == :bullish && last_price >= pool.level) || (bias == :bearish && last_price <= pool.level))
          :liquidity_sweep
        else
          :bos_only
        end

      # Extra filter: Supertrend & ADX on 15m
      st_sig = s.m15.supertrend_signal
      strong = begin
        ta = TechnicalAnalysis::Adx.calculate(s.m15.hlc, period: 14).first&.adx.to_f
        ta >= 18
      rescue StandardError
        true
      end
      return nil unless strong &&
                        ((bias == :bullish && st_sig == :long_entry) || (bias == :bearish && st_sig == :short_entry))

      Result.new(
        direction: (bias == :bullish ? :bullish : :bearish),
        why: "4H=#{bias} 1H_trend=#{h1_trend} 15m=#{confirm}",
        meta: { bos: !!bos, choch: !!choch, ob: !!ob_zone, fvg: fvg_list.any?, pools: pools.any? }
      )
    end
  end
end
