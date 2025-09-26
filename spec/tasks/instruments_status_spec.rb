require 'rails_helper'
require 'rake'

RSpec.describe 'instruments rake tasks' do
  include ActiveSupport::Testing::TimeHelpers

  before(:all) do
    Rails.application.load_tasks if Rake::Task.tasks.empty?
  end

  let(:task) { Rake::Task['instruments:status'] }

  before do
    Rails.cache.clear
    Setting.delete_all
    task.reenable
  end

  after do
    task.reenable
  end

  context 'when no import metadata exists' do
    it 'exits with status 1' do
      expect { task.invoke }.to raise_error(SystemExit) do |error|
        expect(error.status).to eq(1)
      end
    end
  end

  context 'when metadata is stale' do
    it 'exits with status 1' do
      travel_to(Time.zone.parse('2024-01-10 10:00:00 UTC')) do
        stale_time = (InstrumentsImporter::CACHE_MAX_AGE + 1.hour).ago
        Setting.put('instruments.last_imported_at', stale_time.iso8601)
        Setting.put('instruments.last_import_duration_sec', 1.0)
        Setting.put('instruments.last_instrument_rows', 1)
        Setting.put('instruments.last_derivative_rows', 1)
        Setting.put('instruments.last_instrument_upserts', 1)
        Setting.put('instruments.last_derivative_upserts', 1)
        Setting.put('instruments.instrument_total', 10)
        Setting.put('instruments.derivative_total', 20)

        expect { task.invoke }.to raise_error(SystemExit) do |error|
          expect(error.status).to eq(1)
        end
      end
    end
  end

  context 'when metadata is fresh' do
    it 'completes successfully' do
      travel_to(Time.zone.parse('2024-01-10 10:00:00 UTC')) do
        Setting.put('instruments.last_imported_at', Time.zone.now.iso8601)
        Setting.put('instruments.last_import_duration_sec', 0.5)
        Setting.put('instruments.last_instrument_rows', 1)
        Setting.put('instruments.last_derivative_rows', 1)
        Setting.put('instruments.last_instrument_upserts', 1)
        Setting.put('instruments.last_derivative_upserts', 1)
        Setting.put('instruments.instrument_total', 10)
        Setting.put('instruments.derivative_total', 20)

        expect { task.invoke }.not_to raise_error
      end
    end
  end
end
