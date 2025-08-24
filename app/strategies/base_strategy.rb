# frozen_string_literal: true

class BaseStrategy
  attr_reader :instrument, :tf, :settings

  def initialize(instrument:, tf: '5m', settings: {})
    @instrument = instrument
    @tf = tf
    @settings = settings
    @last_signal_at = nil
  end

  # Called on every new bar close
  def on_bar(bar:)
    # override
  end

  # Return a SignalStruct or nil
  def entry_signal
    nil
  end

  # Return a SignalStruct or nil (given active position side)
  def exit_signal(position_side:, entry_at:, ltp:)
    nil
  end

  protected

  def recent_signal_cooldown?(seconds:)
    return false unless @last_signal_at

    (Time.now - @last_signal_at) < seconds
  end

  def mark_signal!
    @last_signal_at = Time.now
  end
end
