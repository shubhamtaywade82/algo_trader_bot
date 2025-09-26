# frozen_string_literal: true

class LlmController < ApplicationController
  # Explicitly require AI modules to ensure they're loaded
  require_relative '../services/ai'
  require_relative '../services/ai/openai_client'
  require_relative '../services/ai/openai_client_v2'
  require_relative '../services/ai/decision_engine'
  def funds
    funds_data = DhanHQ::Models::Funds.fetch
    render json: {
      available_balance: funds_data.available_balance,
      sod_limit: funds_data.sod_limit,
      collateral_amount: funds_data.collateral_amount,
      receiveable_amount: funds_data.receiveable_amount,
      utilized_amount: funds_data.utilized_amount,
      blocked_payout_amount: funds_data.blocked_payout_amount,
      withdrawable_balance: funds_data.withdrawable_balance
    }
  rescue StandardError => e
    Rails.logger.error("[LLM::Funds] Error: #{e.message}")
    render json: { error: 'DhanHQ API error', message: e.message }, status: :service_unavailable
  end

  def positions
    positions_data = DhanHQ::Models::Position.all
    render json: positions_data.map do |position|
      {
        dhan_client_id: position.dhan_client_id,
        trading_symbol: position.trading_symbol,
        security_id: position.security_id,
        position_type: position.position_type,
        exchange_segment: position.exchange_segment,
        product_type: position.product_type,
        buy_avg: position.buy_avg,
        buy_qty: position.buy_qty,
        cost_price: position.cost_price,
        sell_avg: position.sell_avg,
        sell_qty: position.sell_qty,
        net_qty: position.net_qty,
        realized_profit: position.realized_profit,
        unrealized_profit: position.unrealized_profit,
        rbi_reference_rate: position.rbi_reference_rate,
        multiplier: position.multiplier,
        carry_forward_buy_qty: position.carry_forward_buy_qty,
        carry_forward_sell_qty: position.carry_forward_sell_qty,
        carry_forward_buy_value: position.carry_forward_buy_value,
        carry_forward_sell_value: position.carry_forward_sell_value,
        day_buy_qty: position.day_buy_qty,
        day_sell_qty: position.day_sell_qty,
        day_buy_value: position.day_buy_value,
        day_sell_value: position.day_sell_value,
        drv_expiry_date: position.drv_expiry_date,
        drv_option_type: position.drv_option_type,
        drv_strike_price: position.drv_strike_price,
        cross_currency: position.cross_currency
      }
    end
  rescue StandardError => e
    Rails.logger.error("[LLM::Positions] Error: #{e.message}")
    render json: { error: 'DhanHQ API error', message: e.message }, status: :service_unavailable
  end

  def orders
    orders_data = DhanHQ::Models::Order.all
    render json: orders_data.map do |order|
      {
        order_id: order.order_id,
        trading_symbol: order.trading_symbol,
        security_id: order.security_id,
        order_type: order.order_type,
        product_type: order.product_type,
        order_side: order.order_side,
        quantity: order.quantity,
        price: order.price,
        trigger_price: order.trigger_price,
        status: order.status,
        order_time: order.order_time,
        exchange_segment: order.exchange_segment,
        validity: order.validity,
        disclosed_quantity: order.disclosed_quantity,
        order_quantity: order.order_quantity,
        filled_quantity: order.filled_quantity,
        pending_quantity: order.pending_quantity,
        average_price: order.average_price,
        exchange_order_id: order.exchange_order_id,
        exchange_time: order.exchange_time,
        rejection_reason: order.rejection_reason,
        rejection_code: order.rejection_code,
        rejection_reason_code: order.rejection_reason_code,
        rejection_reason_message: order.rejection_reason_message,
        rejection_reason_code_message: order.rejection_reason_code_message,
        rejection_reason_code_message_1: order.rejection_reason_code_message_1,
        rejection_reason_code_message_2: order.rejection_reason_code_message_2,
        rejection_reason_code_message_3: order.rejection_reason_code_message_3,
        rejection_reason_code_message_4: order.rejection_reason_code_message_4,
        rejection_reason_code_message_5: order.rejection_reason_code_message_5,
        rejection_reason_code_message_6: order.rejection_reason_code_message_6,
        rejection_reason_code_message_7: order.rejection_reason_code_message_7,
        rejection_reason_code_message_8: order.rejection_reason_code_message_8,
        rejection_reason_code_message_9: order.rejection_reason_code_message_9,
        rejection_reason_code_message_10: order.rejection_reason_code_message_10,
        rejection_reason_code_message_11: order.rejection_reason_code_message_11,
        rejection_reason_code_message_12: order.rejection_reason_code_message_12,
        rejection_reason_code_message_13: order.rejection_reason_code_message_13,
        rejection_reason_code_message_14: order.rejection_reason_code_message_14,
        rejection_reason_code_message_15: order.rejection_reason_code_message_15,
        rejection_reason_code_message_16: order.rejection_reason_code_message_16,
        rejection_reason_code_message_17: order.rejection_reason_code_message_17,
        rejection_reason_code_message_18: order.rejection_reason_code_message_18,
        rejection_reason_code_message_19: order.rejection_reason_code_message_19,
        rejection_reason_code_message_20: order.rejection_reason_code_message_20,
        rejection_reason_code_message_21: order.rejection_reason_code_message_21,
        rejection_reason_code_message_22: order.rejection_reason_code_message_22,
        rejection_reason_code_message_23: order.rejection_reason_code_message_23,
        rejection_reason_code_message_24: order.rejection_reason_code_message_24,
        rejection_reason_code_message_25: order.rejection_reason_code_message_25,
        rejection_reason_code_message_26: order.rejection_reason_code_message_26,
        rejection_reason_code_message_27: order.rejection_reason_code_message_27,
        rejection_reason_code_message_28: order.rejection_reason_code_message_28,
        rejection_reason_code_message_29: order.rejection_reason_code_message_29,
        rejection_reason_code_message_30: order.rejection_reason_code_message_30,
        rejection_reason_code_message_31: order.rejection_reason_code_message_31,
        rejection_reason_code_message_32: order.rejection_reason_code_message_32,
        rejection_reason_code_message_33: order.rejection_reason_code_message_33,
        rejection_reason_code_message_34: order.rejection_reason_code_message_34,
        rejection_reason_code_message_35: order.rejection_reason_code_message_35,
        rejection_reason_code_message_36: order.rejection_reason_code_message_36,
        rejection_reason_code_message_37: order.rejection_reason_code_message_37,
        rejection_reason_code_message_38: order.rejection_reason_code_message_38,
        rejection_reason_code_message_39: order.rejection_reason_code_message_39,
        rejection_reason_code_message_40: order.rejection_reason_code_message_40,
        rejection_reason_code_message_41: order.rejection_reason_code_message_41,
        rejection_reason_code_message_42: order.rejection_reason_code_message_42,
        rejection_reason_code_message_43: order.rejection_reason_code_message_43,
        rejection_reason_code_message_44: order.rejection_reason_code_message_44,
        rejection_reason_code_message_45: order.rejection_reason_code_message_45,
        rejection_reason_code_message_46: order.rejection_reason_code_message_46,
        rejection_reason_code_message_47: order.rejection_reason_code_message_47,
        rejection_reason_code_message_48: order.rejection_reason_code_message_48,
        rejection_reason_code_message_49: order.rejection_reason_code_message_49,
        rejection_reason_code_message_50: order.rejection_reason_code_message_50,
        rejection_reason_code_message_51: order.rejection_reason_code_message_51,
        rejection_reason_code_message_52: order.rejection_reason_code_message_52,
        rejection_reason_code_message_53: order.rejection_reason_code_message_53,
        rejection_reason_code_message_54: order.rejection_reason_code_message_54,
        rejection_reason_code_message_55: order.rejection_reason_code_message_55,
        rejection_reason_code_message_56: order.rejection_reason_code_message_56,
        rejection_reason_code_message_57: order.rejection_reason_code_message_57,
        rejection_reason_code_message_58: order.rejection_reason_code_message_58,
        rejection_reason_code_message_59: order.rejection_reason_code_message_59,
        rejection_reason_code_message_60: order.rejection_reason_code_message_60,
        rejection_reason_code_message_61: order.rejection_reason_code_message_61,
        rejection_reason_code_message_62: order.rejection_reason_code_message_62,
        rejection_reason_code_message_63: order.rejection_reason_code_message_63,
        rejection_reason_code_message_64: order.rejection_reason_code_message_64,
        rejection_reason_code_message_65: order.rejection_reason_code_message_65,
        rejection_reason_code_message_66: order.rejection_reason_code_message_66,
        rejection_reason_code_message_67: order.rejection_reason_code_message_67,
        rejection_reason_code_message_68: order.rejection_reason_code_message_68,
        rejection_reason_code_message_69: order.rejection_reason_code_message_69,
        rejection_reason_code_message_70: order.rejection_reason_code_message_70,
        rejection_reason_code_message_71: order.rejection_reason_code_message_71,
        rejection_reason_code_message_72: order.rejection_reason_code_message_72,
        rejection_reason_code_message_73: order.rejection_reason_code_message_73,
        rejection_reason_code_message_74: order.rejection_reason_code_message_74,
        rejection_reason_code_message_75: order.rejection_reason_code_message_75,
        rejection_reason_code_message_76: order.rejection_reason_code_message_76,
        rejection_reason_code_message_77: order.rejection_reason_code_message_77,
        rejection_reason_code_message_78: order.rejection_reason_code_message_78,
        rejection_reason_code_message_79: order.rejection_reason_code_message_79,
        rejection_reason_code_message_80: order.rejection_reason_code_message_80,
        rejection_reason_code_message_81: order.rejection_reason_code_message_81,
        rejection_reason_code_message_82: order.rejection_reason_code_message_82,
        rejection_reason_code_message_83: order.rejection_reason_code_message_83,
        rejection_reason_code_message_84: order.rejection_reason_code_message_84,
        rejection_reason_code_message_85: order.rejection_reason_code_message_85,
        rejection_reason_code_message_86: order.rejection_reason_code_message_86,
        rejection_reason_code_message_87: order.rejection_reason_code_message_87,
        rejection_reason_code_message_88: order.rejection_reason_code_message_88,
        rejection_reason_code_message_89: order.rejection_reason_code_message_89,
        rejection_reason_code_message_90: order.rejection_reason_code_message_90,
        rejection_reason_code_message_91: order.rejection_reason_code_message_91,
        rejection_reason_code_message_92: order.rejection_reason_code_message_92,
        rejection_reason_code_message_93: order.rejection_reason_code_message_93,
        rejection_reason_code_message_94: order.rejection_reason_code_message_94,
        rejection_reason_code_message_95: order.rejection_reason_code_message_95,
        rejection_reason_code_message_96: order.rejection_reason_code_message_96,
        rejection_reason_code_message_97: order.rejection_reason_code_message_97,
        rejection_reason_code_message_98: order.rejection_reason_code_message_98,
        rejection_reason_code_message_99: order.rejection_reason_code_message_99,
        rejection_reason_code_message_100: order.rejection_reason_code_message_100
      }
    end
  rescue StandardError => e
    Rails.logger.error("[LLM::Orders] Error: #{e.message}")
    render json: { error: 'DhanHQ API error', message: e.message }, status: :service_unavailable
  end

  def spot
    sym = params.require(:underlying)
    spot_price = Market::SpotFetcher.call(symbol: sym).to_f
    render json: { symbol: sym, spot: spot_price }
  rescue StandardError => e
    Rails.logger.error("[LLM::Spot] Error: #{e.message}")
    render json: { error: 'Failed to fetch spot price', message: e.message }, status: :service_unavailable
  end

  def quote
    sid = params.require(:securityId).to_i
    q = Quotes::Reader.fetch(security_id: sid)
    render json: { securityId: sid, ltp: q[:ltp].to_f }
  rescue StandardError => e
    Rails.logger.error("[LLM::Quote] Error: #{e.message}")
    render json: { error: 'Failed to fetch quote', message: e.message }, status: :service_unavailable
  end

  def option_chain
    u = params.require(:underlying)
    e = params.require(:expiry)
    chain = Option::ChainAnalyzer.new(underlying: u, expiry: e).build
    render json: chain
  rescue StandardError => e
    Rails.logger.error("[LLM::OptionChain] Error: #{e.message}")
    render json: { error: 'Failed to fetch option chain', message: e.message }, status: :service_unavailable
  end

  # ---- Execution endpoints used by MCP tool calls ----
  def place_bracket_order
    return render json: { dry_run: true, note: 'paper or execution disabled' } if paper? || !exec_enabled?

    sid = params.require(:securityId).to_i
    qty = params.require(:qty).to_i
    slp = params.require(:sl_pct).to_f
    tpp = params.require(:tp_pct).to_f

    res = Execution::OrderExecutor.place_bracket(
      security_id: sid, quantity: qty, sl_pct: slp, tp_pct: tpp
    )
    render json: res
  end

  def modify_order
    return render json: { dry_run: true } if paper? || !exec_enabled?

    oid = params.require(:orderId)
    pr  = params.require(:params).permit!
    render json: Orders::Adjuster.modify(order_id: oid, **pr.to_h.symbolize_keys)
  end

  def cancel_order
    return render json: { dry_run: true } if paper? || !exec_enabled?

    oid = params.require(:orderId)
    render json: Orders::Manager.cancel(order_id: oid)
  end

  # ---- AI Analysis endpoints ----
  def analyze_market
    market_data = params.require(:market_data).permit!
    pp market_data
    context = params.require(:context).permit!

    ai_client = ::Ai::OpenAIClientV2.new
    result = ai_client.analyze_market_conditions(market_data.to_h, context.to_h)

    if result[:success]
      render json: { analysis: result[:data] }
    else
      render json: { error: result[:error] }, status: :service_unavailable
    end
  rescue StandardError => e
    Rails.logger.error("[LLM::AnalyzeMarket] Error: #{e.message}")
    render json: { error: 'AI analysis failed', message: e.message }, status: :service_unavailable
  end

  def trading_recommendations
    signals = params.require(:signals)
    market_data = params.require(:market_data).permit!
    portfolio_state = params.require(:portfolio_state).permit!

    ai_client = ::Ai::OpenAIClientV2.new
    result = ai_client.generate_trading_recommendations(
      signals, market_data.to_h, portfolio_state.to_h
    )

    if result[:success]
      render json: { recommendations: result[:data] }
    else
      render json: { error: result[:error] }, status: :service_unavailable
    end
  rescue StandardError => e
    Rails.logger.error("[LLM::TradingRecommendations] Error: #{e.message}")
    render json: { error: 'AI recommendations failed', message: e.message }, status: :service_unavailable
  end

  def ai_decision
    market_data = params.require(:market_data).permit!
    signals = params.require(:signals)
    portfolio_state = params.require(:portfolio_state).permit!

    decision_engine = ::Ai::DecisionEngine.new
    result = decision_engine.make_decision(
      market_data.to_h, signals, portfolio_state.to_h
    )

    if result[:success]
      render json: {
        decision: result[:data][:decision],
        confidence: result[:data][:confidence],
        reasoning: result[:data][:reasoning]
      }
    else
      render json: { error: result[:error] }, status: :service_unavailable
    end
  rescue StandardError => e
    Rails.logger.error("[LLM::AIDecision] Error: #{e.message}")
    render json: { error: 'AI decision failed', message: e.message }, status: :service_unavailable
  end

  def test_ai_connection
    ai_client = ::Ai::OpenAIClientV2.new
    result = ai_client.test_connection

    if result[:success]
      render json: {
        message: result[:message],
        ollama_url: ai_client.current_ollama_url,
        use_ollama: ai_client.use_ollama?
      }
    else
      render json: {
        error: result[:error],
        ollama_url: ai_client.current_ollama_url,
        use_ollama: ai_client.use_ollama?
      }, status: :service_unavailable
    end
  rescue StandardError => e
    Rails.logger.error("[LLM::TestAIConnection] Error: #{e.message}")
    render json: { error: 'AI connection test failed', message: e.message }, status: :service_unavailable
  end

  def custom_analysis
    prompt = params.require(:prompt)

    ai_client = ::Ai::OpenAIClientV2.new
    result = ai_client.make_request(prompt)

    if result[:success]
      render json: { analysis: result[:data] }
    else
      render json: { error: result[:error] }, status: :service_unavailable
    end
  rescue StandardError => e
    Rails.logger.error("[LLM::CustomAnalysis] Error: #{e.message}")
    render json: { error: 'Custom analysis failed', message: e.message }, status: :service_unavailable
  end

  private

  def paper? = ActiveModel::Type::Boolean.new.cast(ENV.fetch('PAPER_MODE', nil))
  def exec_enabled? = ActiveModel::Type::Boolean.new.cast(ENV.fetch('EXECUTE_ORDERS', nil))
end
