# frozen_string_literal: true

module Instruments
  # Resolves instruments using the actual schema conventions (enums for exchange
  # / segment, canonical symbol names, and index aliases). Supports fuzzy
  # lookups across `symbol_name`, `display_name`, `underlying_symbol`, and
  # `security_id` while always scoping by exchange/segment when those are known.
  class Resolver
    INDEX_ALIASES = {
      'NIFTY' => { symbol: 'NIFTY', exchange: 'nse', segment: 'index' },
      'BANKNIFTY' => { symbol: 'BANKNIFTY', exchange: 'nse', segment: 'index' },
      'SENSEX' => { symbol: 'SENSEX', exchange: 'bse', segment: 'index' }
    }.freeze

    UPPER_REPLACE_SQL = "REPLACE(upper(%{column}), ' ', '') = ?".freeze

    def initialize(scope: Instrument.all)
      @scope = scope
    end

    def call(symbol:, exchange: nil, segment: nil, security_id: nil)
      return nil if [symbol, security_id].all?(&:blank?)

      token = normalize(symbol)
      alias_attrs = INDEX_ALIASES[token] || {}

      exchange_candidates = candidate_exchanges(exchange, alias_attrs[:exchange])
      segment_candidates = candidate_segments(segment, alias_attrs[:segment])
      symbol_candidates = candidate_symbols(symbol, token, alias_attrs[:symbol], security_id)

      exchange_candidates.each do |ex_key|
        segment_candidates.each do |seg_key|
          normalized = attrs_normalized_value(symbol, token, alias_attrs[:symbol], security_id)

          symbol_candidates.each do |attrs|
            instrument = locate(attrs, ex_key, seg_key)
            return instrument if instrument
          end

          instrument = locate_normalized(normalized, ex_key, seg_key)
          return instrument if instrument
        end
      end

      nil
    end

    private

    def candidate_exchanges(explicit, alias_value)
      keys = []
      keys << normalize_exchange(explicit)
      keys << normalize_exchange(alias_value)
      keys << nil
      keys.compact.uniq
    end

    def candidate_segments(explicit, alias_value)
      keys = []
      keys << normalize_segment(explicit)
      keys << normalize_segment(alias_value)
      keys << nil
      keys.compact.uniq
    end

    def candidate_symbols(symbol, token, alias_symbol, security_id)
      raw = symbol.to_s.strip
      alias_symbol ||= token

      candidates = []
      [raw, token, alias_symbol].compact.uniq.each do |value|
        next if value.blank?

        candidates << { symbol_name: value }
        candidates << { display_name: value }
        candidates << { underlying_symbol: value }
      end

      candidates << { security_id: security_id.to_s } if security_id.present?
      candidates.uniq
    end

    def attrs_normalized_value(symbol, token, alias_symbol, security_id)
      return security_id.to_s.strip if security_id.present?

      normalize(alias_symbol || token || symbol)
    end

    def locate(attrs, exchange_key, segment_key)
      rel = apply_scope(exchange_key, segment_key)
      sanitized = attrs.compact.transform_values do |value|
        value.is_a?(String) ? value.strip : value
      end
      return nil if sanitized.empty?

      rel.where(sanitized).first
    end

    def locate_normalized(token, exchange_key, segment_key)
      return nil if token.blank?

      rel = apply_scope(exchange_key, segment_key)
      rel.where(UPPER_REPLACE_SQL % { column: 'symbol_name' }, token).first ||
        rel.where(UPPER_REPLACE_SQL % { column: 'display_name' }, token).first ||
        rel.where(UPPER_REPLACE_SQL % { column: 'underlying_symbol' }, token).first
    end

    def apply_scope(exchange_key, segment_key)
      rel = @scope
      if exchange_key.present?
        db_value = Instrument.exchanges[exchange_key]
        rel = rel.where(exchange: db_value) if db_value
      end
      if segment_key.present?
        db_value = Instrument.segments[segment_key]
        rel = rel.where(segment: db_value) if db_value
      end
      rel
    end

    def normalize_exchange(value)
      return nil if value.blank?

      str = value.to_s.strip
      key = str.downcase
      return key if Instrument.exchanges.key?(key)

      upper = str.upcase
      Instrument.exchanges.key(upper)
    end

    def normalize_segment(value)
      return nil if value.blank?

      str = value.to_s.strip
      key = str.downcase
      return key if Instrument.segments.key?(key)

      upper = str.upcase
      Instrument.segments.key(upper)
    end

    def normalize(value)
      value.to_s.upcase.delete(' ')
    end
  end
end
