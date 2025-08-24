# frozen_string_literal: true

SignalStruct = Struct.new(
  :type,       # :entry or :exit
  :side,       # :buy_ce / :buy_pe or :close
  :reason,     # short string
  :confidence, # 0.0..1.0
  :context,    # hash of indicator values
  keyword_init: true
)
