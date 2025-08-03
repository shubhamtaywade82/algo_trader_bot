# frozen_string_literal: true

module Strategies
  class HolyGrailStrategy < ApplicationService
    attr_reader :instrument, :series, :signal_components

    def initialize(instrument, series: nil)
      @instrument = instrument
      @series = series || instrument.candles('5')
      @signal_components = []
    end

    def call
      analyze_indicators
      analyze_smc
      analyze_option_chain

      total_score = signal_components.sum { _1[:score] }
      result = classify_signal(total_score)

      {
        symbol: instrument.symbol,
        timestamp: Time.current,
        result: result,
        total_score: total_score,
        components: signal_components,
        action: result == :buy_ce || result == :buy_pe ? :trade : :hold,
        sl: dynamic_stop_loss,
        tp: dynamic_take_profit,
        trail: dynamic_trailing_step
      }
    end

    private

    def analyze_indicators
      [
        Indicators::SupertrendSignal,
        Indicators::RsiSignal,
        Indicators::MacdSignal,
        Indicators::AdxSignal
      ].each do |klass|
        signal_components << klass.call(series: series)
      end
    end

    def analyze_smc
      [
        SMC::Bos,
        SMC::Choch
      ].each do |klass|
        signal_components << klass.call(series: series)
      end
    end

    def analyze_option_chain
      option_data = instrument.fetch_option_chain
      oc_score = OptionChainAnalyzer.call(option_chain: option_data, spot: series.closes.last)
      signal_components << oc_score if oc_score
    end

    def classify_signal(score)
      if score >= 75 && series.supertrend_signal == :long_entry
        :buy_ce
      elsif score >= 75 && series.supertrend_signal == :short_entry
        :buy_pe
      else
        :hold
      end
    end

    def dynamic_stop_loss
      atr = RubyTechnicalAnalysis::Atr.new(series: series.closes, period: 14).call.last
      spot = series.closes.last
      series.supertrend_signal == :long_entry ? spot - (2.5 * atr) : spot + (2.5 * atr)
    end

    def dynamic_take_profit
      atr = RubyTechnicalAnalysis::Atr.new(series: series.closes, period: 14).call.last
      spot = series.closes.last
      series.supertrend_signal == :long_entry ? spot + (4 * atr) : spot - (4 * atr)
    end

    def dynamic_trailing_step
      atr = RubyTechnicalAnalysis::Atr.new(series: series.closes, period: 14).call.last
      atr * 0.5
    end
  end
end
