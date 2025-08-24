require 'rails_helper'

RSpec.describe CandleSeries do
  describe '#normalise_candles and #load_from_raw' do
    let(:series) { described_class.new(symbol: 'TEST') }

    it 'normalizes array based candles with numeric values' do
      ts = 1_700_000_000
      data = [[ts, '1', '2', '0.5', '1.5', nil]]
      norm = series.normalise_candles(data).first

      expect(norm[:timestamp]).to eq(Time.zone.at(ts))
      expect(norm[:open]).to eq(1.0)
      expect(norm[:high]).to eq(2.0)
      expect(norm[:low]).to eq(0.5)
      expect(norm[:close]).to eq(1.5)
      expect(norm[:volume]).to eq(0)
    end

    it 'normalizes hash based candles and defaults volume' do
      ts = 1_700_000_100
      data = [{ 'timestamp' => ts, 'open' => '1', 'high' => '2', 'low' => '0.5', 'close' => '1.5' }]
      norm = series.normalise_candles(data).first

      expect(norm[:timestamp]).to eq(Time.zone.at(ts))
      expect(norm[:volume]).to eq(0)
      expect(norm[:open]).to eq(1.0)
    end

    it 'loads candles into objects with proper timestamp' do
      ts = 1_700_000_200
      series.load_from_raw([[ts, 1, 2, 0.5, 1.5, 10]])
      expect(series.candles.first.timestamp).to eq(Time.zone.at(ts))
    end
  end
end
