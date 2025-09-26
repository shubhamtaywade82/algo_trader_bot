# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'AutopilotController', type: :request do
  describe 'GET /autopilot/status' do
    it 'returns autopilot status' do
      get '/autopilot/status'

      expect(response).to have_http_status(:ok)
      expect(json_response).to include('running', 'mode', 'strategies')
    end
  end

  describe 'POST /autopilot/start' do
    it 'starts autopilot' do
      post '/autopilot/start'

      expect(response).to have_http_status(:ok)
      expect(json_response).to include('message')
    end
  end

  describe 'POST /autopilot/stop' do
    it 'stops autopilot' do
      post '/autopilot/stop'

      expect(response).to have_http_status(:ok)
      expect(json_response).to include('message')
    end
  end

  describe 'POST /autopilot/configure' do
    let(:config) do
      {
        strategies: ['OptionsScalper'],
        risk_limit: 0.02,
        paper_mode: true
      }
    end

    it 'configures autopilot' do
      post '/autopilot/configure', params: { config: config }

      expect(response).to have_http_status(:ok)
      expect(json_response).to include('message')
    end
  end
end
