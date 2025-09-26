# frozen_string_literal: true

# AI client service for AI-powered trading decisions
# Uses Ollama for local development, OpenAI for production
class Ai::OpenAIClient
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :api_key, :string
  attribute :model, :string, default: 'llama3.1:8b-instruct-q5_K_M'
  attribute :max_tokens, :integer, default: 1000
  attribute :temperature, :decimal, default: 0.7
  attribute :enabled, :boolean, default: true
  attribute :timeout, :integer, default: 30
  attribute :retry_attempts, :integer, default: 3
  attribute :use_ollama, :boolean, default: true
  attribute :ollama_url, :string, default: 'http://localhost:11434'

  def initialize(attributes = {})
    super
    @api_key ||= ENV.fetch('OPENAI_API_KEY', nil)
    @use_ollama = ENV.fetch('USE_OLLAMA', 'true').downcase == 'true'
    # Force Windows Ollama URL for WSL environment
    @ollama_url = 'http://172.29.128.1:11434'
    Rails.logger.info "AI Client initialized with Ollama URL: #{@ollama_url}"
  end

  def enabled?
    enabled
  end

  def current_ollama_url
    @ollama_url
  end

  # Analyze market conditions and provide trading insights
  def analyze_market_conditions(market_data, context = {})
    return { success: false, error: 'Not enabled' } unless enabled?

    prompt = build_market_analysis_prompt(market_data, context)
    response = make_request(prompt)

    if response[:success]
      parse_market_analysis(response[:data])
    else
      response
    end
  end

  # Generate trading recommendations based on signals
  def generate_trading_recommendations(signals, market_data, portfolio_state)
    return { success: false, error: 'Not enabled' } unless enabled?

    prompt = build_trading_recommendations_prompt(signals, market_data, portfolio_state)
    response = make_request(prompt)

    if response[:success]
      parse_trading_recommendations(response[:data])
    else
      response
    end
  end

  # Analyze risk and provide risk management insights
  def analyze_risk(positions, market_data, risk_metrics)
    return { success: false, error: 'Not enabled' } unless enabled?

    prompt = build_risk_analysis_prompt(positions, market_data, risk_metrics)
    response = make_request(prompt)

    if response[:success]
      parse_risk_analysis(response[:data])
    else
      response
    end
  end

  # Generate strategy optimization suggestions
  def optimize_strategy(strategy_name, performance_data, market_conditions)
    return { success: false, error: 'Not enabled' } unless enabled?

    prompt = build_strategy_optimization_prompt(strategy_name, performance_data, market_conditions)
    response = make_request(prompt)

    if response[:success]
      parse_strategy_optimization(response[:data])
    else
      response
    end
  end

  # Generate market sentiment analysis
  def analyze_market_sentiment(market_data, news_data = {})
    return { success: false, error: 'Not enabled' } unless enabled?

    prompt = build_sentiment_analysis_prompt(market_data, news_data)
    response = make_request(prompt)

    if response[:success]
      parse_sentiment_analysis(response[:data])
    else
      response
    end
  end

  # Test the AI connection
  def test_connection
    return { success: false, error: 'Not enabled' } unless enabled?

    prompt = "Hello, this is a test message. Please respond with 'Connection successful'."
    response = make_request(prompt)

    if response[:success]
      service_name = use_ollama? ? 'Ollama' : 'OpenAI'
      { success: true, message: "#{service_name} connection successful" }
    else
      { success: false, error: response[:error] }
    end
  end

  private

  def make_request(prompt)
    if use_ollama?
      make_ollama_request(prompt)
    else
      return { success: false, error: 'API key not configured' } unless api_key.present?

      payload = {
        model: model,
        messages: [
          {
            role: 'system',
            content: 'You are an expert algorithmic trading AI assistant specializing in options trading and risk management. Provide concise, actionable insights.'
          },
          {
            role: 'user',
            content: prompt
          }
        ],
        max_tokens: max_tokens,
        temperature: temperature
      }

      retry_with_backoff do
        response = make_openai_request(payload)
        parse_openai_response(response)
      end
    end
  rescue StandardError => e
    { success: false, error: e.message }
  end

  def use_ollama?
    use_ollama
  end

  def make_ollama_request(prompt)
    uri = URI("#{ollama_url}/api/generate")

    http = Net::HTTP.new(uri.host, uri.port)
    http.read_timeout = timeout
    http.open_timeout = timeout

    payload = {
      model: model,
      prompt: build_ollama_prompt(prompt),
      stream: false,
      options: {
        temperature: temperature,
        num_predict: max_tokens
      }
    }

    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'
    request.body = payload.to_json

    response = http.request(request)
    parse_ollama_response(response)
  end

  def make_openai_request(payload)
    uri = URI('https://api.openai.com/v1/chat/completions')

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = timeout
    http.open_timeout = timeout

    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{api_key}"
    request['Content-Type'] = 'application/json'
    request.body = payload.to_json

    response = http.request(request)
    JSON.parse(response.body)
  end

  def parse_openai_response(response)
    if response['error']
      { success: false, error: response['error']['message'] }
    elsif response['choices']&.first&.dig('message', 'content')
      { success: true, data: response['choices'].first['message']['content'] }
    else
      { success: false, error: 'Unexpected response format' }
    end
  end

  def parse_ollama_response(response)
    if response.code.to_i == 200
      parsed_response = JSON.parse(response.body)
      if parsed_response['response']
        { success: true, data: parsed_response['response'] }
      else
        { success: false, error: 'No response from Ollama' }
      end
    else
      { success: false, error: "Ollama request failed: #{response.code}" }
    end
  rescue JSON::ParserError => e
    { success: false, error: "Failed to parse Ollama response: #{e.message}" }
  end

  def build_ollama_prompt(user_prompt)
    system_prompt = 'You are an expert algorithmic trading AI assistant specializing in options trading and risk management. Provide concise, actionable insights.'

    "#{system_prompt}\n\nUser: #{user_prompt}\n\nAssistant:"
  end

  def detect_ollama_url
    # Try to detect Windows host IP from WSL
    if File.exist?('/proc/version') && File.read('/proc/version').include?('microsoft')
      # We're in WSL, try to get Windows host IP
      windows_ip = get_windows_host_ip
      return "http://#{windows_ip}:11434" if windows_ip
    end

    # Default to localhost
    'http://localhost:11434'
  end

  def get_windows_host_ip
    # Get the default gateway which is usually the Windows host in WSL
    result = `ip route show default | awk '/default/ {print $3}'`.strip
    result.empty? ? nil : result
  rescue StandardError
    nil
  end

  def retry_with_backoff
    attempts = 0
    begin
      yield
    rescue StandardError => e
      attempts += 1
      if attempts < retry_attempts
        sleep(2**attempts) # Exponential backoff
        retry
      else
        { success: false, error: e.message }
      end
    end
  end

  def build_market_analysis_prompt(market_data, context)
    <<~PROMPT
      Analyze the following market data and provide trading insights:

      Market Data:
      - Volatility: #{market_data[:volatility]&.round(3) || 'N/A'}
      - Trend Strength: #{market_data[:trend_strength]&.round(3) || 'N/A'}
      - Volume: #{market_data[:volume] || 'N/A'}
      - Price Action: #{market_data[:price_action] || 'N/A'}

      Context:
      - Current Time: #{context[:current_time] || Time.now.strftime('%H:%M')}
      - Market Session: #{context[:market_session] || 'Regular'}
      - Recent Performance: #{context[:recent_performance] || 'N/A'}

      Please provide:
      1. Market condition assessment (Bullish/Bearish/Neutral)
      2. Key risk factors to watch
      3. Recommended trading approach
      4. Specific indicators to monitor

      Keep response concise and actionable.
    PROMPT
  end

  def build_trading_recommendations_prompt(signals, market_data, portfolio_state)
    <<~PROMPT
      Based on the following trading signals and market conditions, provide recommendations:

      Signals:
      #{signals.map { |s| "- #{s[:strategy]}: #{s[:side]} #{s[:confidence]&.round(2)} confidence" }.join("\n")}

      Market Data:
      - Volatility: #{market_data[:volatility]&.round(3) || 'N/A'}
      - Trend: #{market_data[:trend_strength]&.round(3) || 'N/A'}

      Portfolio State:
      - Active Positions: #{portfolio_state[:active_positions] || 0}
      - Total P&L: #{portfolio_state[:total_pnl]&.round(2) || 'N/A'}
      - Risk Level: #{portfolio_state[:risk_level] || 'N/A'}

      Please provide:
      1. Signal validation (which signals to act on)
      2. Position sizing recommendations
      3. Risk management advice
      4. Market timing insights

      Keep response concise and actionable.
    PROMPT
  end

  def build_risk_analysis_prompt(positions, market_data, risk_metrics)
    <<~PROMPT
      Analyze the current risk profile and provide risk management insights:

      Current Positions:
      #{positions.map { |p| "- #{p[:instrument]}: #{p[:side]} #{p[:quantity]} @ #{p[:entry_price]}" }.join("\n")}

      Risk Metrics:
      - Portfolio Risk: #{risk_metrics[:portfolio_risk]&.round(2) || 'N/A'}%
      - Max Drawdown: #{risk_metrics[:max_drawdown]&.round(2) || 'N/A'}%
      - VaR: #{risk_metrics[:var]&.round(2) || 'N/A'}%

      Market Conditions:
      - Volatility: #{market_data[:volatility]&.round(3) || 'N/A'}
      - Trend: #{market_data[:trend_strength]&.round(3) || 'N/A'}

      Please provide:
      1. Risk assessment (Low/Medium/High)
      2. Specific risk factors
      3. Recommended actions
      4. Position adjustments needed

      Keep response concise and actionable.
    PROMPT
  end

  def build_strategy_optimization_prompt(strategy_name, performance_data, market_conditions)
    <<~PROMPT
      Optimize the following trading strategy based on performance data:

      Strategy: #{strategy_name}

      Performance Data:
      - Win Rate: #{performance_data[:win_rate]&.round(2) || 'N/A'}%
      - Avg Win: #{performance_data[:avg_win]&.round(2) || 'N/A'}
      - Avg Loss: #{performance_data[:avg_loss]&.round(2) || 'N/A'}
      - Sharpe Ratio: #{performance_data[:sharpe_ratio]&.round(2) || 'N/A'}

      Market Conditions:
      - Volatility Regime: #{market_conditions[:volatility_regime] || 'N/A'}
      - Trend Environment: #{market_conditions[:trend_environment] || 'N/A'}

      Please provide:
      1. Performance analysis
      2. Parameter optimization suggestions
      3. Market condition adaptations
      4. Risk management improvements

      Keep response concise and actionable.
    PROMPT
  end

  def build_sentiment_analysis_prompt(market_data, news_data)
    <<~PROMPT
      Analyze market sentiment based on the following data:

      Market Data:
      - Volatility: #{market_data[:volatility]&.round(3) || 'N/A'}
      - Price Action: #{market_data[:price_action] || 'N/A'}
      - Volume: #{market_data[:volume] || 'N/A'}

      News Data:
      #{news_data[:headlines]&.map { |h| "- #{h}" }&.join("\n") || 'No news data available'}

      Please provide:
      1. Sentiment assessment (Bullish/Bearish/Neutral)
      2. Key sentiment drivers
      3. Market impact analysis
      4. Trading implications

      Keep response concise and actionable.
    PROMPT
  end

  def parse_market_analysis(response_text)
    {
      success: true,
      data: {
        analysis: response_text,
        timestamp: Time.current,
        type: 'market_analysis'
      }
    }
  end

  def parse_trading_recommendations(response_text)
    {
      success: true,
      data: {
        recommendations: response_text,
        timestamp: Time.current,
        type: 'trading_recommendations'
      }
    }
  end

  def parse_risk_analysis(response_text)
    {
      success: true,
      data: {
        risk_analysis: response_text,
        timestamp: Time.current,
        type: 'risk_analysis'
      }
    }
  end

  def parse_strategy_optimization(response_text)
    {
      success: true,
      data: {
        optimization: response_text,
        timestamp: Time.current,
        type: 'strategy_optimization'
      }
    }
  end

  def parse_sentiment_analysis(response_text)
    {
      success: true,
      data: {
        sentiment: response_text,
        timestamp: Time.current,
        type: 'sentiment_analysis'
      }
    }
  end
end
