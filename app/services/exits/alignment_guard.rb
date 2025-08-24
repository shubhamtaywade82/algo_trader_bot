# app/services/exits/alignment_guard.rb
class Exits::AlignmentGuard < ApplicationService
  def initialize(order:, underlying_symbol:)
    @order = order
    @symbol = underlying_symbol
  end

  def call
    inst = Instrument.segment_index.find_by(symbol_name: @symbol) || Instrument.segment_equity.find_by(display_name: @symbol)
    return true unless inst

    sig = inst.supertrend_signal(interval: '5') # :long_entry / :short_entry
    return true unless sig

    long = (@order.side.to_s == 'buy') # we buy premium for CE/PE
    # If CE → need long_entry; if PE → need short_entry; otherwise suggest exit
    return (sig == :long_entry) if @order.cp == 'CE'
    return (sig == :short_entry) if @order.cp == 'PE'

    true
  end
end
