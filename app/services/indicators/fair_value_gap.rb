module Indicators
  class FairValueGap
    def initialize(series)
      @series = series
    end

    def detect
      fvg_zones = []
      @series.each_cons(3).with_index do |(c1, c2, c3), i|
        if c3.low > c1.high
          fvg_zones << { index: i + 1, from: c1.high, to: c3.low, direction: :up }
        elsif c3.high < c1.low
          fvg_zones << { index: i + 1, from: c3.high, to: c1.low, direction: :down }
        end
      end
      fvg_zones
    end
  end
end
