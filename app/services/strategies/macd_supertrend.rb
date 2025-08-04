module Strategies
  class MacdSupertrend < BaseIndicatorStrategy
    def signal?
      macd = instrument.macd
      supertrend = instrument.supertrend_signal

      macd_line = macd[:macd]
      signal_line = macd[:signal]

      if macd_line > signal_line && supertrend == :long_entry
        :buy_ce
      elsif macd_line < signal_line && supertrend == :short_entry
        :buy_pe
      end
    end

    def confidence_score = 75
    def reason_text = "MACD/ST: MACD=#{instrument.macd[:macd]}, Signal=#{instrument.macd[:signal]}, Supertrend=#{instrument.supertrend_signal}"
  end
end

