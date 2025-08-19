# frozen_string_literal: true

module Mtf
  class SeriesLoader
    Result = Struct.new(:m5, :m15, :h1, :h4, keyword_init: true)

    # instrument: your Instrument record
    # base_interval: '5' (we’ll resample to 15/60/240)
    def self.load(instrument:, base_interval: '5')
      raw = instrument.intraday_ohlc(interval: base_interval)
      return nil if raw.blank?

      m5 = CandleSeries.new(symbol: instrument.symbol_name, interval: base_interval)
      m5.load_from_raw(raw)

      m15 = Mtf::Resampler.to(m5, minutes: 15)
      h1  = Mtf::Resampler.to(m5, minutes: 60)
      h4  = Mtf::Resampler.to(m5, minutes: 240)

      Result.new(m5: m5, m15: m15, h1: h1, h4: h4)
    end
  end
end
