# frozen_string_literal: true

module Mtf
  class Resampler
    Bucket = Struct.new(:ts, :o, :h, :l, :c, :vol, keyword_init: true)

    # series: CandleSeries on 1m/3m/5m; minutes: 15 / 60 / 240
    def self.to(series, minutes:)
      raise 'series empty' if series.candles.empty?

      step   = minutes * 60
      out    = []
      bucket = nil

      series.candles.each do |bar|
        t = bar.timestamp.to_i
        bt = t - (t % step) # bucket start

        if bucket.nil? || bucket.ts != bt
          out << bucket_to_candle(bucket) if bucket
          bucket = Bucket.new(ts: bt, o: bar.open, h: bar.high, l: bar.low, c: bar.close, vol: bar.volume.to_i)
        else
          bucket.h = [bucket.h, bar.high].max
          bucket.l   = [bucket.l, bar.low].min
          bucket.c   = bar.close
          bucket.vol = bucket.vol.to_i + bar.volume.to_i
        end
      end

      out << bucket_to_candle(bucket) if bucket

      CandleSeries.new(symbol: series.symbol, interval: minutes.to_s).tap do |cs|
        out.each { |c| cs.add_candle(c) }
      end
    end

    def self.bucket_to_candle(b)
      Candle.new(
        ts: Time.at(b.ts).in_time_zone,
        open: b.o,
        high: b.h,
        low: b.l,
        close: b.c,
        volume: b.vol.to_i
      )
    end
  end
end
