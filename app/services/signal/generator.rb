# frozen_string_literal: true

# Signal generation service that coordinates multiple strategies
# and generates trading signals based on market conditions
class Signal::Generator
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :enabled_strategies
  attribute :max_signals_per_instrument, :integer, default: 1
  attribute :signal_cooldown, :integer, default: 300 # 5 minutes in seconds
  attribute :min_confidence_threshold, :decimal, default: 0.6

  def initialize(attributes = {})
    super
    @signal_cache = {}
    @last_signal_time = {}

    # Set default enabled strategies if not provided
    self.enabled_strategies ||= default_strategies
  end

  # Generate signals for a given instrument
  def generate_signals(instrument, market_data)
    return [] unless valid_instrument?(instrument)
    return [] unless valid_market_data?(market_data)

    # Check cooldown period
    return [] if signal_cooldown_active?(instrument)

    signals = []
    enabled_strategies.each do |strategy_class|
      next unless strategy_class.enabled?

      begin
        signal = generate_signal_for_strategy(strategy_class, instrument, market_data)
        signals << signal if signal && signal_valid?(signal)
      rescue StandardError => e
        Rails.logger.error "Signal generation failed for #{strategy_class.name}: #{e.message}"
        next
      end
    end

    # Filter and rank signals
    filtered_signals = filter_and_rank_signals(signals, instrument)

    # Update cache and cooldown
    update_signal_cache(instrument, filtered_signals)

    filtered_signals
  end

  # Generate signal for a specific strategy
  def generate_signal_for_strategy(strategy_class, instrument, market_data)
    strategy = strategy_class.new
    return nil unless strategy.valid_for_trading?(instrument, market_data)

    # Prepare market data for strategy
    prepared_data = prepare_market_data(instrument, market_data)

    # Execute strategy
    trade_plan = strategy.execute(instrument, prepared_data)
    return nil unless trade_plan

    # Convert trade plan to signal
    build_signal(trade_plan, strategy_class, instrument, market_data)
  end

  # Check if any position should exit
  def check_exit_signals(positions, market_data)
    exit_signals = []

    positions.each do |position|
      next unless position.active?

      strategy_class = find_strategy_class(position.strategy)
      next unless strategy_class

      begin
        strategy = strategy_class.new
        exit_signals << build_exit_signal(position, strategy_class, market_data) if strategy.should_exit?(position, market_data)
      rescue StandardError => e
        Rails.logger.error "Exit signal check failed for position #{position.id}: #{e.message}"
        next
      end
    end

    exit_signals
  end

  # Get signal statistics
  def signal_stats
    {
      total_strategies: enabled_strategies.count,
      active_strategies: enabled_strategies.count,
      signal_cache_size: @signal_cache.size,
      last_signal_times: @last_signal_time
    }
  end

  private

  def default_strategies
    [
      Strategy::OptionsScalper,
      Strategy::TrendFollower,
      Strategy::BreakoutScalper,
      Strategy::MeanReversion
    ]
  end

  def valid_instrument?(instrument)
    instrument.present? &&
      instrument.derivative? &&
      instrument.active?
  end

  def valid_market_data?(market_data)
    market_data.present? &&
      market_data[:ltp].present? &&
      market_data[:ltp] > 0 &&
      market_data[:candles].present? &&
      market_data[:candles].length >= 20
  end

  def signal_cooldown_active?(instrument)
    last_time = @last_signal_time[instrument.id]
    return false unless last_time

    Time.current - last_time < signal_cooldown.seconds
  end

  def prepare_market_data(instrument, market_data)
    # Add instrument-specific data
    prepared_data = market_data.dup

    # Add option chain data if available
    if instrument.option?
      prepared_data[:option_chain] = instrument.fetch_option_chain
      prepared_data[:greeks] = calculate_greeks(instrument, market_data[:ltp])
    end

    # Add additional market context
    prepared_data[:market_hours] = market_hours?
    prepared_data[:volatility] = calculate_volatility(market_data[:candles])
    prepared_data[:trend_strength] = calculate_trend_strength(market_data[:candles])

    prepared_data
  end

  def calculate_greeks(instrument, current_price)
    return {} unless instrument.option?

    # Simplified Greeks calculation
    # In practice, you'd use a proper options pricing model
    {
      delta: calculate_delta(instrument, current_price),
      gamma: calculate_gamma(instrument, current_price),
      theta: calculate_theta(instrument, current_price),
      vega: calculate_vega(instrument, current_price)
    }
  end

  def calculate_delta(instrument, current_price)
    # Simplified delta calculation
    return 0.5 unless instrument.strike_price && instrument.underlying_price

    strike = instrument.strike_price
    underlying = instrument.underlying_price
    time_to_expiry = (instrument.expiry_date - Date.current).to_f / 365.0

    # Black-Scholes delta approximation
    d1 = (Math.log(underlying / strike) + ((0.05 + ((0.2**2) / 2)) * time_to_expiry)) / (0.2 * Math.sqrt(time_to_expiry))
    normal_cdf(d1)
  end

  def normal_cdf(x)
    # Approximation of normal CDF
    0.5 * (1 + Math.erf(x / Math.sqrt(2)))
  end

  def calculate_gamma(instrument, current_price)
    # Simplified gamma calculation
    0.01 # Placeholder
  end

  def calculate_theta(instrument, current_price)
    # Simplified theta calculation
    -0.05 # Placeholder
  end

  def calculate_vega(instrument, current_price)
    # Simplified vega calculation
    0.1 # Placeholder
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

  def market_hours?
    current_time = Time.current
    market_open = current_time.change(hour: 9, min: 15)
    market_close = current_time.change(hour: 15, min: 30)

    current_time >= market_open && current_time <= market_close
  end

  def build_signal(trade_plan, strategy_class, instrument, market_data)
    {
      id: SecureRandom.uuid,
      instrument: instrument,
      strategy: strategy_class.name,
      side: trade_plan[:side],
      quantity: trade_plan[:quantity],
      entry_price: trade_plan[:entry_price],
      stop_loss: trade_plan[:stop_loss],
      take_profit: trade_plan[:take_profit],
      confidence: trade_plan[:confidence],
      risk_reward_ratio: trade_plan[:risk_reward_ratio],
      expected_profit: trade_plan[:expected_profit],
      expected_loss: trade_plan[:expected_loss],
      market_data: market_data,
      created_at: Time.current,
      type: 'entry'
    }
  end

  def build_exit_signal(position, strategy_class, market_data)
    {
      id: SecureRandom.uuid,
      position_id: position.id,
      instrument: position.instrument,
      strategy: strategy_class.name,
      side: position.side,
      quantity: position.quantity,
      current_price: market_data[:ltp],
      current_pnl: calculate_current_pnl(position, market_data[:ltp]),
      reason: determine_exit_reason(position, market_data),
      created_at: Time.current,
      type: 'exit'
    }
  end

  def calculate_current_pnl(position, current_price)
    case position.side.upcase
    when 'BUY'
      (current_price - position.entry_price) * position.quantity
    when 'SELL'
      (position.entry_price - current_price) * position.quantity
    else
      0
    end
  end

  def determine_exit_reason(position, market_data)
    # Determine why the position should exit
    if time_based_exit?(position)
      'time_based'
    elsif profit_target_hit?(position, market_data[:ltp])
      'profit_target'
    elsif stop_loss_hit?(position, market_data[:ltp])
      'stop_loss'
    else
      'strategy_signal'
    end
  end

  def time_based_exit?(position)
    position.created_at < 30.minutes.ago
  end

  def profit_target_hit?(position, current_price)
    current_pnl = calculate_current_pnl(position, current_price)
    current_pnl >= position.expected_profit * 0.8
  end

  def stop_loss_hit?(position, current_price)
    current_pnl = calculate_current_pnl(position, current_price)
    current_pnl <= -position.expected_loss
  end

  def signal_valid?(signal)
    signal.present? &&
      signal[:confidence] >= min_confidence_threshold &&
      signal[:quantity] > 0 &&
      signal[:entry_price] > 0 &&
      signal[:stop_loss] > 0 &&
      signal[:take_profit] > 0
  end

  def filter_and_rank_signals(signals, instrument)
    # Remove duplicate signals for the same instrument
    unique_signals = signals.uniq { |s| [s[:instrument].id, s[:side]] }

    # Limit signals per instrument
    limited_signals = unique_signals.first(max_signals_per_instrument)

    # Rank by confidence and other factors
    limited_signals.sort_by do |signal|
      -signal[:confidence] # Higher confidence first
    end
  end

  def update_signal_cache(instrument, signals)
    @signal_cache[instrument.id] = signals
    @last_signal_time[instrument.id] = Time.current if signals.any?
  end

  def find_strategy_class(strategy_name)
    case strategy_name
    when 'OptionsScalper' then Strategy::OptionsScalper
    when 'TrendFollower' then Strategy::TrendFollower
    when 'BreakoutScalper' then Strategy::BreakoutScalper
    when 'MeanReversion' then Strategy::MeanReversion
    else
      nil
    end
  end
end
