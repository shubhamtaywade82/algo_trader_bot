# frozen_string_literal: true

# Mean reversion strategy for trading against the trend
# Uses Bollinger Bands and RSI for overbought/oversold conditions
class Strategy::MeanReversion < Strategy::Base
  attribute :lookback_periods, :integer, default: 20
  attribute :bollinger_periods, :integer, default: 20
  attribute :bollinger_std_dev, :decimal, default: 2.0
  attribute :rsi_periods, :integer, default: 14
  attribute :rsi_oversold, :decimal, default: 30.0
  attribute :rsi_overbought, :decimal, default: 70.0
  attribute :min_confidence, :decimal, default: 0.6
  attribute :max_trade_duration, :integer, default: 45 # minutes
  attribute :reversion_threshold, :decimal, default: 0.02 # 2%

  def initialize(attributes = {})
    super(attributes.merge(name: 'MeanReversion'))
  end

  def execute(instrument, market_data)
    return nil unless valid_for_trading?(instrument, market_data)

    reversion_signal = analyze_mean_reversion(instrument, market_data)
    return nil unless reversion_signal

    build_trade_plan(
      instrument,
      reversion_signal[:side],
      market_data[:ltp],
      market_data,
      confidence: reversion_signal[:confidence],
      stop_loss_percentage: reversion_signal[:stop_loss_percentage] || 0.025,
      risk_reward_ratio: reversion_signal[:risk_reward_ratio] || 1.5
    )
  end

  def should_exit?(position, market_data)
    time_based_exit?(position, max_trade_duration.minutes) ||
      profit_target_hit?(position, market_data[:ltp]) ||
      stop_loss_hit?(position, market_data[:ltp]) ||
      mean_reversion_complete?(position, market_data) ||
      trend_continuing?(position, market_data)
  end

  private

  def market_conditions_valid?(market_data)
    super(market_data) &&
      market_data[:candles].present? &&
      market_data[:candles].length >= [bollinger_periods, rsi_periods, lookback_periods].max
  end

  def analyze_mean_reversion(instrument, market_data)
    candles = market_data[:candles]
    return nil unless candles&.length >= [bollinger_periods, rsi_periods].max

    # Calculate technical indicators
    bollinger_bands = calculate_bollinger_bands(candles)
    rsi = calculate_rsi(candles)
    return nil unless bollinger_bands && rsi

    # Check for oversold/overbought conditions
    signal = detect_reversion_signal(candles.last, bollinger_bands, rsi)
    return nil unless signal

    # Validate signal with additional conditions
    return nil unless validate_reversion_signal(signal, candles, market_data)

    build_reversion_signal(signal, bollinger_bands, rsi, market_data)
  end

  def calculate_bollinger_bands(candles)
    return nil unless candles.length >= bollinger_periods

    closes = candles.last(bollinger_periods).map { |c| c[:close] }
    return nil if closes.empty?

    # Calculate SMA
    sma = closes.sum / closes.length.to_f

    # Calculate standard deviation
    variance = closes.map { |price| (price - sma)**2 }.sum / closes.length
    std_dev = Math.sqrt(variance)

    {
      upper: sma + (bollinger_std_dev * std_dev),
      middle: sma,
      lower: sma - (bollinger_std_dev * std_dev),
      std_dev: std_dev
    }
  end

  def calculate_rsi(candles)
    return nil unless candles.length >= rsi_periods + 1

    closes = candles.last(rsi_periods + 1).map { |c| c[:close] }
    return nil if closes.length < 2

    # Calculate price changes
    changes = closes.each_cons(2).map { |a, b| b - a }
    return nil if changes.empty?

    # Separate gains and losses
    gains = changes.map { |change| [change, 0].max }
    losses = changes.map { |change| [-change, 0].max }

    # Calculate average gains and losses
    avg_gains = gains.sum / gains.length.to_f
    avg_losses = losses.sum / losses.length.to_f

    return 50.0 if avg_losses == 0 # Avoid division by zero

    # Calculate RSI
    rs = avg_gains / avg_losses
    rsi = 100 - (100 / (1 + rs))
    rsi.round(2)
  end

  def detect_reversion_signal(last_candle, bollinger_bands, rsi)
    current_price = last_candle[:close]
    upper_band = bollinger_bands[:upper]
    lower_band = bollinger_bands[:lower]
    middle_band = bollinger_bands[:middle]

    # Check for oversold condition (potential buy)
    if current_price <= lower_band && rsi <= rsi_oversold
      {
        side: 'BUY',
        type: 'oversold',
        distance_from_band: (lower_band - current_price) / lower_band,
        rsi_value: rsi,
        band_position: 'lower'
      }
    # Check for overbought condition (potential sell)
    elsif current_price >= upper_band && rsi >= rsi_overbought
      {
        side: 'SELL',
        type: 'overbought',
        distance_from_band: (current_price - upper_band) / upper_band,
        rsi_value: rsi,
        band_position: 'upper'
      }
    end
  end

  def validate_reversion_signal(signal, candles, market_data)
    # Check if price is truly at extreme levels
    return false unless signal[:distance_from_band] >= reversion_threshold

    # Check for divergence (price vs RSI)
    return false unless divergence_confirms_signal?(signal, candles)

    # Check volume confirmation
    return false unless volume_confirms_reversion?(market_data)

    # Check for reversal patterns
    reversal_pattern_confirms?(signal, candles)
  end

  def divergence_confirms_signal?(signal, candles)
    return true unless candles.length >= 10

    # Simple divergence check - price making new lows/highs but RSI not
    recent_candles = candles.last(10)
    prices = recent_candles.map { |c| c[:close] }

    case signal[:side]
    when 'BUY'
      # Price making new lows but RSI not (bullish divergence)
      price_trend = prices.last < prices.first
      # This is a simplified check - in practice, you'd calculate RSI for each period
      price_trend
    when 'SELL'
      # Price making new highs but RSI not (bearish divergence)
      price_trend = prices.last > prices.first
      price_trend
    else
      false
    end
  end

  def volume_confirms_reversion?(market_data)
    return true unless market_data[:volume].present?

    # Check if volume is increasing (confirms reversal)
    avg_volume = calculate_average_volume(market_data)
    return true unless avg_volume > 0

    current_volume = market_data[:volume]
    current_volume >= avg_volume * 0.8 # At least 80% of average volume
  end

  def calculate_average_volume(market_data)
    return 0 unless market_data[:candles]&.length >= 10

    recent_candles = market_data[:candles].last(10)
    volumes = recent_candles.map { |c| c[:volume] || 0 }
    volumes.sum / volumes.length.to_f
  end

  def reversal_pattern_confirms?(signal, candles)
    return true unless candles.length >= 5

    recent_candles = candles.last(5)
    closes = recent_candles.map { |c| c[:close] }

    case signal[:side]
    when 'BUY'
      # Look for hammer or doji patterns
      hammer_pattern?(recent_candles.last) || doji_pattern?(recent_candles.last)
    when 'SELL'
      # Look for shooting star or doji patterns
      shooting_star_pattern?(recent_candles.last) || doji_pattern?(recent_candles.last)
    else
      false
    end
  end

  def hammer_pattern?(candle)
    body_size = (candle[:close] - candle[:open]).abs
    lower_shadow = [candle[:open], candle[:close]].min - candle[:low]
    upper_shadow = candle[:high] - [candle[:open], candle[:close]].max

    body_size > 0 && lower_shadow > body_size * 2 && upper_shadow < body_size * 0.5
  end

  def shooting_star_pattern?(candle)
    body_size = (candle[:close] - candle[:open]).abs
    lower_shadow = [candle[:open], candle[:close]].min - candle[:low]
    upper_shadow = candle[:high] - [candle[:open], candle[:close]].max

    body_size > 0 && upper_shadow > body_size * 2 && lower_shadow < body_size * 0.5
  end

  def doji_pattern?(candle)
    body_size = (candle[:close] - candle[:open]).abs
    total_range = candle[:high] - candle[:low]

    body_size < total_range * 0.1 # Body is less than 10% of total range
  end

  def build_reversion_signal(signal, bollinger_bands, rsi, market_data)
    confidence = calculate_reversion_confidence(signal, bollinger_bands, rsi, market_data)
    return nil if confidence < min_confidence

    {
      side: signal[:side],
      confidence: confidence,
      stop_loss_percentage: calculate_reversion_stop_loss_percentage(signal),
      risk_reward_ratio: calculate_reversion_risk_reward_ratio(signal),
      rsi_value: rsi,
      band_position: signal[:band_position],
      distance_from_band: signal[:distance_from_band],
      bollinger_bands: bollinger_bands
    }
  end

  def calculate_reversion_confidence(signal, bollinger_bands, rsi, market_data)
    # Base confidence from distance from band
    distance_confidence = [signal[:distance_from_band] * 10, 1.0].min

    # RSI confidence
    rsi_confidence = calculate_rsi_confidence(rsi, signal[:side])

    # Volume confidence
    volume_confidence = calculate_volume_confidence(market_data)

    # Pattern confidence
    pattern_confidence = 0.7 # Simplified - would be calculated from actual patterns

    # Weighted confidence
    (distance_confidence * 0.3 +
     rsi_confidence * 0.3 +
     volume_confidence * 0.2 +
     pattern_confidence * 0.2).round(3)
  end

  def calculate_rsi_confidence(rsi, side)
    case side
    when 'BUY'
      case rsi
      when 0..20 then 1.0
      when 20..30 then 0.8
      when 30..40 then 0.6
      else 0.3
      end
    when 'SELL'
      case rsi
      when 80..100 then 1.0
      when 70..80 then 0.8
      when 60..70 then 0.6
      else 0.3
      end
    else
      0.5
    end
  end

  def calculate_volume_confidence(market_data)
    return 0.5 unless market_data[:volume].present?

    avg_volume = calculate_average_volume(market_data)
    return 0.5 unless avg_volume > 0

    volume_ratio = market_data[:volume] / avg_volume
    case volume_ratio
    when 0..0.5 then 0.3
    when 0.5..0.8 then 0.6
    when 0.8..1.2 then 0.8
    when 1.2..2.0 then 1.0
    else 0.9
    end
  end

  def calculate_reversion_stop_loss_percentage(signal)
    # Wider stops for mean reversion (trend can continue)
    base_stop = 0.025
    distance_adjustment = signal[:distance_from_band] * 0.01
    [base_stop - distance_adjustment, 0.015].max
  end

  def calculate_reversion_risk_reward_ratio(signal)
    # Lower R:R for mean reversion (higher win rate, lower reward)
    base_ratio = 1.5
    distance_adjustment = signal[:distance_from_band] * 0.5
    base_ratio + distance_adjustment
  end

  def mean_reversion_complete?(position, market_data)
    return false unless market_data[:candles]&.length >= 5

    recent_candles = market_data[:candles].last(5)
    current_price = market_data[:ltp]

    # Check if price has moved back towards the mean
    case position.side
    when 'BUY'
      # Check if price has moved up significantly from entry
      current_price > position.entry_price * 1.01 # 1% move up
    when 'SELL'
      # Check if price has moved down significantly from entry
      current_price < position.entry_price * 0.99 # 1% move down
    else
      false
    end
  end

  def trend_continuing?(position, market_data)
    return false unless market_data[:candles]&.length >= 10

    recent_candles = market_data[:candles].last(10)
    closes = recent_candles.map { |c| c[:close] }

    # Check if trend is continuing against our position
    case position.side
    when 'BUY'
      # Check if price continues to fall (trend continuing)
      closes.last < closes.first * 0.98 # 2% decline
    when 'SELL'
      # Check if price continues to rise (trend continuing)
      closes.last > closes.first * 1.02 # 2% rise
    else
      false
    end
  end
end
