namespace :instruments do
  desc 'Import instruments from DhanHQ CSV'
  task import: :environment do
    pp 'Starting instruments import...'
    start_time = Time.current

    begin
      InstrumentsImporter.import_from_url

      duration = Time.current - start_time
      pp "\nImport completed successfully in #{duration.round(2)} seconds!"
      pp "Total Instruments: #{Instrument.count}"
      pp "Total Derivatives: #{Derivative.count}"

      # Show some stats
      pp "\n--- Stats ---"
      pp "NSE Instruments: #{Instrument.nse.count}"
      pp "BSE Instruments: #{Instrument.bse.count}"
      pp "NSE Derivatives: #{Derivative.nse.count}"
      pp "BSE Derivatives: #{Derivative.bse.count}"
      pp "Options: #{Derivative.options.count}"
      pp "Futures: #{Derivative.futures.count}"
      pp 'Instruments: Instrument.count'
      pp 'Derivatives: Derivative.count'
      pp "TOTAL: #{Instrument.count + Derivative.count}"
    rescue StandardError => e
      pp "Import failed: #{e.message}"
      pp e.backtrace.join("\n")
    end
  end

  desc 'Clear all instruments and derivatives'
  task clear: :environment do
    pp 'Clearing all instruments and derivatives...'
    Derivative.delete_all
    Instrument.delete_all
    pp 'Cleared successfully!'
  end

  desc 'Reimport (clear and import)'
  task reimport: %i[clear import]
end

# Provide aliases for legacy singular namespace usage.
namespace :instrument do
  desc 'Alias for instruments:import'
  task import: 'instruments:import'

  desc 'Alias for instruments:clear'
  task clear: 'instruments:clear'

  desc 'Alias for instruments:reimport'
  task reimport: 'instruments:reimport'
end
