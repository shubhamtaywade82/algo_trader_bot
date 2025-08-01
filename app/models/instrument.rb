class Instrument < ApplicationRecord
  include InstrumentHelpers

  has_many :derivatives, dependent: :destroy

  accepts_nested_attributes_for :derivatives, allow_destroy: true

  # API Methods
  def fetch_option_chain(expiry = nil)
    expiry ||= expiry_list.first
    data = DhanHQ::Models::OptionChain.fetch(
      underlying_scrip: security_id.to_i,
      underlying_seg: exchange_segment,
      expiry: expiry
    )
    return nil unless data

    filtered_data = filter_option_chain_data(data)

    { last_price: data['last_price'], oc: filtered_data }
  rescue StandardError => e
    Rails.logger.error("Failed to fetch Option Chain for Instrument #{security_id}: #{e.message}")
    nil
  end

  def filter_option_chain_data(data)
    data['oc'].select do |_strike, option_data|
      call_data = option_data['ce']
      put_data = option_data['pe']

      has_call_values = call_data && call_data.except('implied_volatility').values.any? do |v|
        numeric_value?(v) && v.to_f.positive?
      end
      has_put_values = put_data && put_data.except('implied_volatility').values.any? do |v|
        numeric_value?(v) && v.to_f.positive?
      end

      has_call_values || has_put_values
    end
  end

  def expiry_list
    DhanHQ::Models::OptionChain.fetch_expiry_list(
      underlying_scrip: security_id.to_i,
      underlying_seg: exchange_segment
    )
  end
end
