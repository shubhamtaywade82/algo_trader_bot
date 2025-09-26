# frozen_string_literal: true

module TestHelpers
  # Helper methods for testing
  def json_response
    JSON.parse(response.body)
  end

  def create_test_market_data
    {
      'volatility' => 0.25,
      'trend_strength' => 0.7,
      'volume' => 1000000,
      'price_action' => 'Bullish'
    }
  end

  def create_test_signals
    [
      {
        'strategy' => 'OptionsScalper',
        'action' => 'BUY',
        'confidence' => 0.8,
        'instrument' => 'NIFTY24000CE',
        'price' => 150.0
      }
    ]
  end

  def create_test_portfolio_state
    {
      'available_cash' => 100000,
      'current_positions' => 2,
      'total_exposure' => 50000
    }
  end

  def mock_ai_response(success: true, data: 'Test AI response')
    {
      success: success,
      data: data,
      error: success ? nil : 'Test error'
    }
  end

  def mock_ollama_response
    {
      'response' => 'Test Ollama response',
      'done' => true
    }
  end
end
