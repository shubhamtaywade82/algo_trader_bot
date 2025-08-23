module PriceMath
  TICK = 0.05

  def self.round_tick(x)
    return nil if x.nil?

    ((x.to_f / TICK).round * TICK).round(2)
  end

  def self.floor_tick(x)
    ((x.to_f / TICK).floor * TICK).round(2)
  end

  def self.ceil_tick(x)
    ((x.to_f / TICK).ceil * TICK).round(2)
  end

  def self.valid_tick?(x)
    # Avoid float fuzziness: work in paise
    ((x.to_f * 100).round % (TICK * 100).to_i).zero?
  end
end