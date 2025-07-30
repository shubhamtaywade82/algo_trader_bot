class Derivative < ApplicationRecord
  include InstrumentHelpers

  belongs_to :instrument
end
