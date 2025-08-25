# app/services/indicators/holy_grail.rb
# frozen_string_literal: true

require 'ruby_technical_analysis'
require 'technical_analysis'

module Indicators
  class HolyGrail < ApplicationService
    RTA = RubyTechnicalAnalysis
    TA  = TechnicalAnalysis

    # Keep the default lens as constants (unchanged)
    EMA_FAST  = 34
    EMA_SLOW  = 100
    RSI_LEN   = 14
    ADX_LEN   = 14
    ATR_LEN   = 20
    MACD_F = 12
    MACD_S = 26
    MACD_SIG = 9

    # New: default gates (used unless overridden via config:)
    DEFAULTS = {
      ema_fast: EMA_FAST,
      ema_slow: EMA_SLOW,
      rsi_len: RSI_LEN,
      adx_len: ADX_LEN,
      atr_len: ATR_LEN,
      macd_f: MACD_F,
      macd_s: MACD_S,
      macd_sig: MACD_SIG,

      # “proceed?” gates
      adx_gate: 20.0, # >= this to allow entries
      rsi_up_min: 40.0, # bullish momentum must be above
      rsi_down_max: 60.0, # bearish momentum must be below

      # sanity for history length (keep ≥ slow MA by default)
      min_candles: EMA_SLOW
    }.freeze

    # Handful of presets you can reuse from callers:
    def self.demo_config
      {
        # keep math stable but relax gates to near-zero so demo always “flows”
        adx_gate: 0.0,
        rsi_up_min: 0.0,
        rsi_down_max: 100.0,
        min_candles: 1 # allow tiny series in demo
      }
    end

    Result = Struct.new(
      :bias, :adx, :momentum, :proceed?,
      :sma50, :ema200, :rsi14, :atr14, :macd, :trend,
      keyword_init: true
    ) do
      def to_h = members.zip(values).to_h
    end

    # ------- ctor -----------------------------------------------------
    def initialize(candles:, config: {})
      @candles = candles # Dhan hash-of-arrays

      @cfg = DEFAULTS.merge((config || {}).transform_keys(&:to_sym))

      min_needed = @cfg[:min_candles].to_i.positive? ? @cfg[:min_candles].to_i : DEFAULTS[:min_candles]
      raise ArgumentError, "need ≥ #{min_needed} candles" if closes.size < min_needed
    end

    # ------- main -----------------------------------------------------
    def call
      # read lengths from cfg (still default to the original)
      ema_fast = @cfg[:ema_fast]
      ema_slow = @cfg[:ema_slow]
      rsi_len  = @cfg[:rsi_len]
      adx_len  = @cfg[:adx_len]
      atr_len  = @cfg[:atr_len]

      sma50  = sma(ema_fast)
      ema200 = ema(ema_slow)
      rsi14  = rsi(rsi_len)
      macd_h = macd_hash
      adx14  = adx(adx_len)
      atr14  = atr(atr_len)

      # bias on MA alignment
      bias =
        if    sma50 > ema200 then :bullish
        elsif sma50 < ema200 then :bearish
        else
          :neutral
        end

      # momentum on MACD+RSI, but use cfg bands now
      rsi_up_min   = @cfg[:rsi_up_min].to_f
      rsi_down_max = @cfg[:rsi_down_max].to_f

      momentum =
        if macd_h[:macd] > macd_h[:signal] && rsi14 >= rsi_up_min
          :up
        elsif macd_h[:macd] < macd_h[:signal] && rsi14 <= rsi_down_max
          :down
        else
          :flat
        end

      # proceed gate with configurable ADX
      adx_gate = @cfg[:adx_gate].to_f

      proceed =
        case bias
        when :bullish
          passed = adx14 >= adx_gate && momentum == :up
          Rails.logger.debug { "[HolyGrail] Not proceeding (bullish): adx=#{adx14} gate=#{adx_gate}, momentum=#{momentum}" } unless passed
          passed
        when :bearish
          passed = adx14 >= adx_gate && momentum == :down
          Rails.logger.debug { "[HolyGrail] Not proceeding (bearish): adx=#{adx14} gate=#{adx_gate}, momentum=#{momentum}" } unless passed
          passed
        else
          Rails.logger.debug { "[HolyGrail] Not proceeding (#{bias}): neutral bias, adx=#{adx14}, momentum=#{momentum}, gate=#{adx_gate}" }
          false
        end

      latest_time = Time.zone.at(stamps.last)
      Rails.logger.debug { "[HolyGrail] (#{latest_time}) proceed?=#{proceed}" }

      trend =
        if ema200 < closes.last && sma50 > ema200 then :up
        elsif ema200 > closes.last && sma50 < ema200 then :down
        else
          :side
        end

      Result.new(
        bias:, adx: adx14, momentum:, proceed?: proceed,
        sma50:, ema200:, rsi14:, atr14:, macd: macd_h, trend:
      )
    end

    private

    def closes = @candles['close'].map(&:to_f)
    def highs  = @candles['high'].map(&:to_f)
    def lows   = @candles['low'].map(&:to_f)
    def stamps = @candles['timestamp'] || []

    def ohlc_rows
      @ohlc_rows ||= highs.each_index.map do |i|
        {
          date_time: Time.zone.at(stamps[i] || 0),
          high: highs[i],
          low: lows[i],
          close: closes[i]
        }
      end
    end

    # — ruby-technical-analysis —
    def sma(len) = closes.last(len).sum / len.to_f
    def ema(len) = RTA::MovingAverages.new(series: closes, period: len).ema
    def rsi(len) = RTA::RelativeStrengthIndex.new(series: closes, period: len).call

    def macd_hash
      m, s, h = RTA::Macd.new(series: closes,
                              fast_period: @cfg[:macd_f],
                              slow_period: @cfg[:macd_s],
                              signal_period: @cfg[:macd_sig]).call
      { macd: m, signal: s, hist: h }
    end

    # — technical_analysis gem —
    def atr(len)
      TA::Atr.calculate(ohlc_rows.last(len * 2), period: len).first.atr
    end

    def adx(len)
      TA::Adx.calculate(ohlc_rows.last(len * 2), period: len).first.adx
    end
  end
end
