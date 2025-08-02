instrument = Instrument.instrument_code_index.find_by security_id: 13
Strategies::BasicTrendStrategy.call(instrument)

raw_data = instrument.intraday_ohlc(interval: '5')
series = CandleSeries.new(symbol: instrument.symbol_name)
series.load_from_raw(raw_data)

breaker_block = Indicators::BreakerBlock.new(series)
breaker_block.identify

Indicators::Calculator.new(series).rsi