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
      search_tokens = candidate_symbols(symbol, token, alias_attrs[:symbol], security_id)

      exchange_candidates.each do |ex_key|
        segment_candidates.each do |seg_key|
          instrument = locate(search_tokens, ex_key, seg_key)
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

      variants = [raw, token, alias_symbol].compact.map(&:strip).reject(&:blank?).uniq

      {
        security_ids: Array(security_id).compact_blank,
        raw_variants: variants,
        normalized_variants: variants.map { |val| normalize(val) }.uniq
      }
    end

    def locate(tokens, exchange_key, segment_key)
      rel = apply_scope(exchange_key, segment_key)
      return rel.where(security_id: tokens[:security_ids]).first if tokens[:security_ids].present?

      query = nil

      unless tokens[:raw_variants].blank?
        raw_values = tokens[:raw_variants]
        query = rel.where(symbol_name: raw_values)
                  .or(rel.where(display_name: raw_values))
                  .or(rel.where(underlying_symbol: raw_values))
      end

      unless tokens[:normalized_variants].blank?
        normalized = tokens[:normalized_variants]
        normalized_query = rel.where("REPLACE(upper(symbol_name), ' ', '') IN (?)", normalized)
                             .or(rel.where("REPLACE(upper(display_name), ' ', '') IN (?)", normalized))
                             .or(rel.where("REPLACE(upper(underlying_symbol), ' ', '') IN (?)", normalized))
        query = query ? query.or(normalized_query) : normalized_query
      end

      query&.first
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
