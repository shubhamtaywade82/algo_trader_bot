module Strategies
  class ObvMacd < BaseIndicatorStrategy
    def signal?
      obv = series.obv
      macd = series.macd
      macd_line = macd.last[:macd]
      signal_line = macd.last[:signal]

      return :buy_ce if obv_trending_up?(obv) && macd_line > signal_line

      :buy_pe if obv_trending_down?(obv) && macd_line < signal_line
    end

    def obv_trending_up?(obv)
      obv.last(3).each_cons(2).all? { |a, b| b > a }
    end

    def obv_trending_down?(obv)
      obv.last(3).each_cons(2).all? { |a, b| b < a }
    end

    def confidence_score = 70
    def reason_text = "OBV/MACD: OBV trend detected, MACD=#{series.macd.last[:macd]}, Signal=#{series.macd.last[:signal]}"
  end
end
