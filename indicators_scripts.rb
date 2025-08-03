instrument = Instrument.instrument_code_index.find_by security_id: 13
raw_data = instrument.intraday_ohlc(interval: '5')
series = CandleSeries.new(symbol: instrument.symbol_name)
series.load_from_raw(raw_data)

breaker_block = Indicators::BreakerBlock.new(series)
breaker_block.identify

Indicators::Calculator.new(series).rsi

Strategies::BasicTrendStrategy.call(instrument)
Strategies::SmartMoneyStrategy.new(instrument).call

reload!; Analysis::OptionsBehaviourAnalyzer.call(option_chain: instrument.fetch_option_chain, expiry: instrument.expiry_list.first, underlying_spot: instrument.ltp, symbol: instrument.symbol_name, historical: instrument.intraday_ohlc) # rubocop:disable Layout/LineLength