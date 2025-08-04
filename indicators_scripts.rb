instrument = Instrument.instrument_code_index.find_by security_id: 13
series = instrument.candles(interval: '5')

breaker_block = Indicators::BreakerBlock.new(series: series)
breaker_block.identify

Indicators::Calculator.new(series).rsi

Strategies::BasicTrendStrategy.call(instrument)
Strategies::SmartMoneyStrategy.new(instrument).call

reload!
Analysis::OptionsBehaviourAnalyzer.call(
  option_chain: instrument.fetch_option_chain,
  expiry: instrument.expiry_list.first,
  underlying_spot: instrument.ltp,
  symbol: instrument.symbol_name,
  historical: instrument.intraday_ohlc
)