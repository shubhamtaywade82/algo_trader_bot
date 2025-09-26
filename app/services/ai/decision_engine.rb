# frozen_string_literal: true

# AI decision engine for enhanced trading decisions
class Ai::DecisionEngine
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :openai_client, default: -> { Ai::OpenAIClient.new }
  attribute :enabled, :boolean, default: true
  attribute :confidence_threshold, :decimal, default: 0.7
  attribute :analysis_interval, :integer, default: 300 # 5 minutes
  attribute :last_analysis, :datetime

  def initialize(attributes = {})
    super
    @analysis_cache = {}
    @decision_history = []
  end

  def enabled?
    enabled
  end

  # Enhance trading signals with AI analysis
  def enhance_signals(signals, market_data, portfolio_state)
    return signals unless enabled? && should_analyze?

    begin
      # Get AI recommendations
      recommendations = openai_client.generate_trading_recommendations(
        signals, market_data, portfolio_state
      )

      return signals unless recommendations[:success]

      # Enhance signals with AI insights
      enhanced_signals = apply_ai_enhancements(signals, recommendations[:data])

      # Cache analysis
      cache_analysis(signals, recommendations[:data])

      enhanced_signals
    rescue StandardError => e
      Rails.logger.error "AI signal enhancement failed: #{e.message}"
      signals # Return original signals on error
    end
  end

  # Make a trading decision based on signals and market data
  def make_decision(market_data, signals, portfolio_state)
    return { success: false, error: 'Not enabled' } unless enabled?

    begin
      # Analyze market conditions
      market_analysis = analyze_market_conditions(market_data)
      return market_analysis unless market_analysis[:success]

      # Get AI recommendations
      recommendations = openai_client.generate_trading_recommendations(
        signals, market_data, portfolio_state
      )
      return recommendations unless recommendations[:success]

      # Make decision based on analysis and recommendations
      decision = make_trading_decision(market_analysis[:data], recommendations[:data], signals)

      { success: true, data: decision }
    rescue StandardError => e
      Rails.logger.error "AI decision making failed: #{e.message}"
      { success: false, error: e.message }
    end
  end

  # Analyze market conditions with AI
  def analyze_market_conditions(market_data, context = {})
    return { success: false, error: 'Not enabled' } unless enabled?

    cache_key = "market_analysis_#{market_data.hash}"
    return @analysis_cache[cache_key] if @analysis_cache[cache_key]

    begin
      analysis = openai_client.analyze_market_conditions(market_data, context)

      if analysis[:success]
        @analysis_cache[cache_key] = analysis
        @last_analysis = Time.current
      end

      analysis
    rescue StandardError => e
      Rails.logger.error "AI market analysis failed: #{e.message}"
      { success: false, error: e.message }
    end
  end

  # Get AI-powered risk assessment
  def assess_risk(positions, market_data, risk_metrics)
    return { success: false, error: 'Not enabled' } unless enabled?

    begin
      risk_analysis = openai_client.analyze_risk(positions, market_data, risk_metrics)

      if risk_analysis[:success]
        # Store decision for audit trail
        @decision_history << {
          type: 'risk_assessment',
          data: risk_analysis[:data],
          timestamp: Time.current
        }
      end

      risk_analysis
    rescue StandardError => e
      Rails.logger.error "AI risk assessment failed: #{e.message}"
      { success: false, error: e.message }
    end
  end

  # Optimize strategy parameters with AI
  def optimize_strategy(strategy_name, performance_data, market_conditions)
    return { success: false, error: 'Not enabled' } unless enabled?

    begin
      optimization = openai_client.optimize_strategy(
        strategy_name, performance_data, market_conditions
      )

      if optimization[:success]
        # Store decision for audit trail
        @decision_history << {
          type: 'strategy_optimization',
          strategy: strategy_name,
          data: optimization[:data],
          timestamp: Time.current
        }
      end

      optimization
    rescue StandardError => e
      Rails.logger.error "AI strategy optimization failed: #{e.message}"
      { success: false, error: e.message }
    end
  end

  # Get market sentiment analysis
  def analyze_sentiment(market_data, news_data = {})
    return { success: false, error: 'Not enabled' } unless enabled?

    begin
      sentiment = openai_client.analyze_market_sentiment(market_data, news_data)

      if sentiment[:success]
        # Store decision for audit trail
        @decision_history << {
          type: 'sentiment_analysis',
          data: sentiment[:data],
          timestamp: Time.current
        }
      end

      sentiment
    rescue StandardError => e
      Rails.logger.error "AI sentiment analysis failed: #{e.message}"
      { success: false, error: e.message }
    end
  end

  # Get AI decision statistics
  def decision_stats
    {
      enabled: enabled?,
      last_analysis: @last_analysis,
      cache_size: @analysis_cache.size,
      decision_count: @decision_history.length,
      recent_decisions: @decision_history.last(10)
    }
  end

  # Clear analysis cache
  def clear_cache
    @analysis_cache.clear
    Rails.logger.info 'AI analysis cache cleared'
  end

  # Get decision history
  def get_decision_history(limit = 50)
    @decision_history.last(limit)
  end

  private

  def should_analyze?
    return true unless @last_analysis

    Time.current - @last_analysis > analysis_interval.seconds
  end

  def apply_ai_enhancements(signals, ai_recommendations)
    enhanced_signals = signals.dup

    # Parse AI recommendations (simplified parsing)
    ai_text = ai_recommendations[:recommendations] || ai_recommendations

    # Apply confidence adjustments based on AI analysis
    enhanced_signals.each do |signal|
      if ai_text.include?('high confidence') || ai_text.include?('strong signal')
        signal[:ai_confidence_boost] = 0.1
        signal[:confidence] = [signal[:confidence] + 0.1, 1.0].min
      elsif ai_text.include?('low confidence') || ai_text.include?('weak signal')
        signal[:ai_confidence_boost] = -0.1
        signal[:confidence] = [signal[:confidence] - 0.1, 0.0].max
      end

      # Add AI insights
      signal[:ai_insights] = extract_ai_insights(ai_text)
    end

    enhanced_signals
  end

  def extract_ai_insights(ai_text)
    # Simple extraction of key insights from AI response
    insights = []

    insights << 'Volatility analysis provided' if ai_text.include?('volatility')

    insights << 'Trend analysis provided' if ai_text.include?('trend')

    insights << 'Risk assessment provided' if ai_text.include?('risk')

    insights << 'Position sizing advice provided' if ai_text.include?('position')

    insights
  end

  def cache_analysis(signals, ai_data)
    cache_key = "signal_analysis_#{signals.hash}"
    @analysis_cache[cache_key] = {
      signals: signals,
      ai_analysis: ai_data,
      timestamp: Time.current
    }

    # Limit cache size
    return unless @analysis_cache.size > 100

    oldest_key = @analysis_cache.keys.first
    @analysis_cache.delete(oldest_key)
  end

  private

  def make_trading_decision(market_analysis, recommendations, signals)
    # Combine market analysis and recommendations to make a decision
    decision = {
      decision: 'HOLD', # Default decision
      confidence: 0.5,
      reasoning: 'No clear signal',
      risk_level: 'MEDIUM',
      recommended_actions: []
    }

    # Analyze market conditions
    if market_analysis['market_condition'] == 'Bullish'
      decision[:decision] = 'BUY'
      decision[:confidence] = 0.8
      decision[:reasoning] = 'Bullish market conditions detected'
    elsif market_analysis['market_condition'] == 'Bearish'
      decision[:decision] = 'SELL'
      decision[:confidence] = 0.8
      decision[:reasoning] = 'Bearish market conditions detected'
    end

    # Apply AI recommendations
    if recommendations.is_a?(Array) && recommendations.any?
      ai_recommendation = recommendations.first
      if ai_recommendation['action'] == 'BUY' && ai_recommendation['confidence'] > 0.7
        decision[:decision] = 'BUY'
        decision[:confidence] = ai_recommendation['confidence']
        decision[:reasoning] = ai_recommendation['reasoning'] || 'AI recommends buy'
      elsif ai_recommendation['action'] == 'SELL' && ai_recommendation['confidence'] > 0.7
        decision[:decision] = 'SELL'
        decision[:confidence] = ai_recommendation['confidence']
        decision[:reasoning] = ai_recommendation['reasoning'] || 'AI recommends sell'
      end
    end

    # Add recommended actions
    decision[:recommended_actions] = recommendations.map { |rec| rec['action'] } if recommendations.is_a?(Array)

    decision
  end
end
