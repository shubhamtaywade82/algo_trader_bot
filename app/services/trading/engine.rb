# frozen_string_literal: true

# Main trading engine that orchestrates the entire trading process
# Coordinates signal generation, processing, and position management
class Trading::Engine
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :enabled, :boolean, default: true
  attribute :trading_instruments
  attribute :signal_generator, default: -> { Signal::Generator.new }
  attribute :signal_processor, default: -> { Signal::Processor.new }
  attribute :market_data_fetcher, default: -> { Market::DataFetcher.new }
  attribute :position_manager, default: -> { Trading::PositionManager.new }
  attribute :update_interval, :integer, default: 30 # seconds
  attribute :max_iterations, :integer, default: 1000
  attribute :error_threshold, :integer, default: 5

  def initialize(attributes = {})
    super
    @running = false
    @iteration_count = 0
    @error_count = 0
    @last_update = nil
    @thread = nil

    # Set default trading instruments if not provided
    self.trading_instruments ||= default_trading_instruments
  end

  # Start the trading engine
  def start!
    return false if @running

    @running = true
    @iteration_count = 0
    @error_count = 0
    @last_update = Time.current

    Rails.logger.info "Trading Engine starting with #{trading_instruments.count} instruments"

    # Start the main trading loop in a separate thread
    @thread = Thread.new do
      main_trading_loop
    end

    true
  end

  # Stop the trading engine
  def stop!
    return false unless @running

    @running = false
    @thread&.join(5) # Wait up to 5 seconds for graceful shutdown

    Rails.logger.info "Trading Engine stopped after #{@iteration_count} iterations"
    true
  end

  # Check if engine is running
  def running?
    @running
  end

  # Get engine status
  def status
    {
      running: @running,
      iteration_count: @iteration_count,
      error_count: @error_count,
      last_update: @last_update,
      active_positions: signal_processor.active_position_count,
      queued_signals: signal_processor.stats[:queued_signals],
      instruments: trading_instruments.count
    }
  end

  # Force process all pending signals
  def process_pending_signals!
    return false unless @running

    begin
      signal_processor.process_pending_signals
      true
    rescue StandardError => e
      Rails.logger.error "Error processing pending signals: #{e.message}"
      @error_count += 1
      false
    end
  end

  # Get trading statistics
  def trading_stats
    {
      engine: status,
      signal_generator: signal_generator.signal_stats,
      signal_processor: signal_processor.stats,
      positions: position_manager.stats
    }
  end

  private

  def default_trading_instruments
    # Get derivative instruments for major indices
    Instrument.where(instrument_type: 'DERIVATIVE')
              .where(symbol_name: %w[NIFTY BANKNIFTY SENSEX])
              .limit(10)
  end

  def main_trading_loop
    Rails.logger.info 'Main trading loop started'

    while @running && @iteration_count < max_iterations
      begin
        process_trading_cycle
        @iteration_count += 1
        @error_count = 0 # Reset error count on successful iteration

        # Sleep for update interval
        sleep(update_interval)
      rescue StandardError => e
        @error_count += 1
        Rails.logger.error "Trading cycle error (#{@error_count}/#{error_threshold}): #{e.message}"

        # Stop if too many errors
        if @error_count >= error_threshold
          Rails.logger.error 'Too many errors, stopping trading engine'
          @running = false
          break
        end

        # Sleep longer on error
        sleep(update_interval * 2)
      end
    end

    Rails.logger.info "Main trading loop ended after #{@iteration_count} iterations"
  end

  def process_trading_cycle
    return unless enabled

    # 1. Fetch market data for all instruments
    market_data = fetch_market_data_for_instruments
    return if market_data.empty?

    # 2. Generate signals for each instrument
    all_signals = []
    trading_instruments.each do |instrument|
      next unless market_data[instrument.id]

      signals = signal_generator.generate_signals(instrument, market_data[instrument.id])
      all_signals.concat(signals) if signals.any?
    end

    # 3. Process entry signals
    if all_signals.any?
      entry_signals = all_signals.select { |s| s[:type] == 'entry' }
      if entry_signals.any?
        Rails.logger.info "Processing #{entry_signals.count} entry signals"
        signal_processor.process_entry_signals(entry_signals)
      end
    end

    # 4. Check exit signals for active positions
    exit_signals = check_exit_signals_for_positions(market_data)
    if exit_signals.any?
      Rails.logger.info "Processing #{exit_signals.count} exit signals"
      signal_processor.process_exit_signals(exit_signals)
    end

    # 5. Update position manager
    position_manager.update_positions(signal_processor.active_positions)

    # 6. Update last update time
    @last_update = Time.current

    # 7. Log cycle completion
    Rails.logger.debug { "Trading cycle completed - Positions: #{signal_processor.active_position_count}, Signals: #{all_signals.count}" }
  end

  def fetch_market_data_for_instruments
    market_data = {}

    trading_instruments.each do |instrument|
      data = fetch_instrument_market_data(instrument)
      market_data[instrument.id] = data if data
    rescue StandardError => e
      Rails.logger.error "Failed to fetch market data for #{instrument.symbol}: #{e.message}"
      next
    end

    market_data
  end

  def fetch_instrument_market_data(instrument)
    # Get current price and basic data
    ltp = instrument.ltp
    return nil unless ltp && ltp > 0

    # Get recent candles
    candles = instrument.intraday_ohlc(limit: 50)
    return nil unless candles&.any?

    # Get volume and other market data
    quote = instrument.depth
    volume = quote&.dig(:volume) || 0

    # Calculate additional metrics
    volatility = calculate_volatility(candles)
    trend_strength = calculate_trend_strength(candles)

    {
      ltp: ltp,
      volume: volume,
      candles: candles,
      volatility: volatility,
      trend_strength: trend_strength,
      bid_ask_spread: calculate_bid_ask_spread(quote),
      oi_ratio: calculate_oi_ratio(instrument),
      timestamp: Time.current
    }
  end

  def calculate_volatility(candles)
    return 0.2 unless candles&.length&.>= 10

    prices = candles.last(10).map { |c| c[:close] }
    return 0.2 if prices.length < 2

    returns = prices.each_cons(2).map { |a, b| Math.log(b / a) }
    variance = returns.map { |r| r**2 }.sum / returns.length
    Math.sqrt(variance * 252) # Annualized volatility
  end

  def calculate_trend_strength(candles)
    return 0.5 unless candles&.length&.>= 20

    # Use Holy Grail indicator for trend strength
    holy_grail = Indicators::HolyGrail.new(candles)
    return 0.5 unless holy_grail.valid?

    holy_grail.strength
  end

  def calculate_bid_ask_spread(quote)
    return 0.1 unless quote&.dig(:bid) && quote.dig(:ask)

    bid = quote[:bid]
    ask = quote[:ask]
    return 0.1 if bid <= 0 || ask <= 0

    (ask - bid) / ((ask + bid) / 2.0)
  end

  def calculate_oi_ratio(instrument)
    return 0.5 unless instrument.option?

    # Simplified OI ratio calculation
    # In practice, you'd get this from the option chain
    0.5
  end

  def check_exit_signals_for_positions(market_data)
    exit_signals = []

    signal_processor.active_positions.each do |position|
      next unless market_data[position.instrument.id]

      # Check if position should exit
      exit_signal = check_position_exit(position, market_data[position.instrument.id])
      exit_signals << exit_signal if exit_signal
    end

    exit_signals
  end

  def check_position_exit(position, market_data)
    # Use the signal generator to check for exit signals
    exit_signals = signal_generator.check_exit_signals([position], market_data)
    exit_signals.first
  end

  def log_engine_status
    Rails.logger.info "Trading Engine Status: #{status}"
  end
end
