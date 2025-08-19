# frozen_string_literal: true

module Mtf
  class Resampler
    Bucket = Struct.new(:ts, :o, :h, :l, :c, :v, keyword_init: true)

    # series: CandleSeries on 1m/3m/5m; to: minutes (15, 60, 240)
    def self.to(series, minutes:)
      raise 'series empty' if series.candles.empty?

      step = minutes * 60
      out  = []
      bucket = nil

      series.candles.each do |c|
        t  = c.timestamp.to_i
        bt = t - (t % step) # bucket start

        if bucket.nil? || bucket.ts != bt
          out << bucket_to_candle(bucket) if bucket
          bucket = Bucket.new(ts: bt, o: c.open, h: c.high, l: c.low, c: c.close, v: c.volume)
        else
          bucket.h = [bucket.h, c.high].max
          bucket.l = [bucket.l, c.low].min
          bucket.c = c.close
          bucket.v += c.volume
        end
      end
      out << bucket_to_candle(bucket) if bucket

      CandleSeries.new(symbol: series.symbol, interval: minutes.to_s).tap do |cs|
        out.each { |k| cs.add_candle(k) }
      end
    end

    def self.bucket_to_candle(b)
      Candle.new(ts: Time.at(b.ts).in_time_zone, open: b.o, high: b.h, low: b.l, close: b.c, volume: b.v)
    end
  end
end
