# frozen_string_literal: true

module Mtf
  class OrderBlock
    Zone = Struct.new(:kind, :index, :open, :high, :low, :close, keyword_init: true) # kind: :demand/:supply

    # last down candle before up-BOS → demand; last up candle before down-BOS → supply
    def self.last_before_bos(series, bos_sig)
      return nil unless bos_sig&.kind == :BOS

      bars = series.candles
      i    = bars.size - 2

      if bos_sig.dir == :up
        # find last bearish candle before BOS index
        while i >= 1 && i > bos_sig.at_index - 20
          c = bars[i]
          return Zone.new(kind: :demand, index: i, open: c.open, high: c.high, low: c.low, close: c.close) if c.close < c.open

          i -= 1
        end
      else
        while i >= 1 && i > bos_sig.at_index - 20
          c = bars[i]
          return Zone.new(kind: :supply, index: i, open: c.open, high: c.high, low: c.low, close: c.close) if c.close > c.open

          i -= 1
        end
      end
      nil
    end

    # price-in-zone test (allow wick tolerance)
    def self.price_touches?(zone, price, pad_pct: 0.0005)
      return false unless zone

      lo = [zone.low, zone.open, zone.close].min
      hi = [zone.high, zone.open, zone.close].max
      pad = (hi - lo) * pad_pct
      (price >= lo - pad) && (price <= hi + pad)
    end
  end
end
