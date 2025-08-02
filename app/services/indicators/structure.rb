module Indicators
  class Structure
    def initialize(series)
      @series = series
    end

    def break_of_structure
      bos_points = []
      @series.candles.each_with_index do |c, i|
        if @series.swing_high?(i) && c.close < c.open
          bos_points << { index: i, type: :bos, direction: :down }
        elsif @series.swing_low?(i) && c.close > c.open
          bos_points << { index: i, type: :bos, direction: :up }
        end
      end
      bos_points
    end
  end
end
