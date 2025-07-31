# frozen_string_literal: true

module InstrumentTypeMapping
  # ------------------------------------------------------------------
  # Parent → child mapping straight from Dhan CSV spec
  # ------------------------------------------------------------------
  PARENT_TO_CHILDREN = {
    'INDEX' => %w[FUTIDX OPTIDX],
    'EQUITY' => %w[FUTSTK OPTSTK],
    # Commodity & Currency don’t have their own high-level codes in CSV,
    # so we treat the futures variant itself as “parent”.
    'FUTCOM' => %w[OPTFUT],
    'FUTCUR' => %w[OPTCUR]
  }.freeze

  # ------------------------------------------------------------------
  # Child → parent lookup (built from the hash above)
  # ------------------------------------------------------------------
  CHILD_TO_PARENT =
    PARENT_TO_CHILDREN.flat_map { |parent, kids| kids.map { |kid| [kid, parent] } }
                      .to_h
                      .freeze

  # --------------------------------------------------
  # Public helpers
  # --------------------------------------------------

  # Given *any* code, return its underlying parent.
  #   underlying_for("FUTIDX")  => "INDEX"
  #   underlying_for("INDEX")   => "INDEX"
  def self.underlying_for(code)
    CHILD_TO_PARENT[code] || code
  end

  # Given an underlying parent, return all derivative codes
  #   derivative_codes_for("INDEX") => ["FUTIDX","OPTIDX"]
  def self.derivative_codes_for(parent_code)
    PARENT_TO_CHILDREN[parent_code] || []
  end

  # Convenience lists
  def self.all_parents  = PARENT_TO_CHILDREN.keys
  def self.all_children = CHILD_TO_PARENT.keys
end
