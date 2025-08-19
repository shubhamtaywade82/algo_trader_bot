# frozen_string_literal: true

module Mtf
  class Structure
    Sig = Struct.new(:kind, :at_index, :price, :dir, keyword_init: true) # kind: :BOS/:CHOCH, dir: :up/:down

    # returns :up (HH/HL) | :down (LH/LL) | :range
    def self.trend(series, lookback: 5)
      highs = series.highs.last(lookback + 3)
      lows  = series.lows.last(lookback + 3)

      return :range if highs.size < 4

      higher_highs = highs.each_cons(2).all? { |a, b| b >= a }
      higher_lows  = lows.each_cons(2).all?  { |a, b| b >= a }
      lower_highs  = highs.each_cons(2).all? { |a, b| b <= a }
      lower_lows   = lows.each_cons(2).all?  { |a, b| b <= a }

      return :up   if higher_highs && higher_lows
      return :down if lower_highs && lower_lows

      :range
    end

    # BOS = current close breaks last swing extreme in trend direction
    def self.bos(series, dir:)
      idx = series.candles.size - 1
      return nil if idx < 3

      last_close = series.candles.last.close
      swings_h   = swing_highs(series, lookback: 2).last(5)
      swings_l   = swing_lows(series,  lookback: 2).last(5)

      if dir == :up && swings_h.last && last_close > swings_h.last[:price]
        return Sig.new(kind: :BOS, at_index: idx, price: last_close, dir: :up)
      elsif dir == :down && swings_l.last && last_close < swings_l.last[:price]
        return Sig.new(kind: :BOS, at_index: idx, price: last_close, dir: :down)
      end

      nil
    end

    # CHOCH = break opposite to prior trend (simple)
    def self.choch(series, prior_dir:)
      idx = series.candles.size - 1
      last_close = series.candles.last.close
      swings_h   = swing_highs(series, lookback: 2).last(5)
      swings_l   = swing_lows(series,  lookback: 2).last(5)

      if prior_dir == :up && swings_l.last && last_close < swings_l.last[:price]
        return Sig.new(kind: :CHOCH, at_index: idx, price: last_close, dir: :down)
      elsif prior_dir == :down && swings_h.last && last_close > swings_h.last[:price]
        return Sig.new(kind: :CHOCH, at_index: idx, price: last_close, dir: :up)
      end

      nil
    end

    def self.swing_highs(series, lookback: 2)
      out = []
      series.candles.each_with_index do |c, i|
        next unless series.swing_high?(i, lookback)

        out << { i: i, price: c.high }
      end
      out
    end

    def self.swing_lows(series, lookback: 2)
      out = []
      series.candles.each_with_index do |c, i|
        next unless series.swing_low?(i, lookback)

        out << { i: i, price: c.low }
      end
      out
    end
  end
end
