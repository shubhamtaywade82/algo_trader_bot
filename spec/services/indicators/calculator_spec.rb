require 'rails_helper'

RSpec.describe Indicators::Calculator do
  let(:series) { CandleSeries.new(symbol: 'T') }

  describe '#bullish_signal? and #bearish_signal?' do
    it 'returns false when there are no candles' do
      calc = described_class.new(series)
      expect(calc.bullish_signal?).to eq(false)
      expect(calc.bearish_signal?).to eq(false)
    end

    it 'returns false when there is only one candle' do
      series.add_candle(Candle.new(ts: Time.zone.now, open: 1, high: 1, low: 1, close: 1, volume: 0))
      calc = described_class.new(series)
      expect(calc.bullish_signal?).to eq(false)
      expect(calc.bearish_signal?).to eq(false)
    end
  end
end
