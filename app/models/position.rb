class Position < ApplicationRecord
  belongs_to :tradable, polymorphic: true, optional: true

  enum :state, { open: 'OPEN', closed: 'CLOSED' }, prefix: :state

  # convenience helpers
  def instrument? = tradable_type == 'Instrument'
  def derivative? = tradable_type == 'Derivative'

  def security_id = self[:security_id] || tradable&.security_id
  def exchange_segment = self[:exchange_segment] || tradable&.exchange_segment
end
