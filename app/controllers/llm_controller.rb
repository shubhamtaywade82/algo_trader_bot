# frozen_string_literal: true

class LlmController < ApplicationController
  def funds
    response = DhanHQ::Models::Account.funds
    if response['status'] == 'success'
      render json: { available: response['data']['availableCash'].to_f }
    else
      render json: { error: 'Failed to fetch funds', details: response }, status: :service_unavailable
    end
  rescue StandardError => e
    Rails.logger.error("[LLM::Funds] Error: #{e.message}")
    render json: { error: 'DhanHQ API error', message: e.message }, status: :service_unavailable
  end

  def positions
    response = DhanHQ::Models::Account.positions
    if response['status'] == 'success'
      render json: response['data']
    else
      render json: { error: 'Failed to fetch positions', details: response }, status: :service_unavailable
    end
  rescue StandardError => e
    Rails.logger.error("[LLM::Positions] Error: #{e.message}")
    render json: { error: 'DhanHQ API error', message: e.message }, status: :service_unavailable
  end

  def orders
    response = DhanHQ::Models::Order.order_book
    if response['status'] == 'success'
      render json: response['data']
    else
      render json: { error: 'Failed to fetch orders', details: response }, status: :service_unavailable
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

  private

  def paper? = ActiveModel::Type::Boolean.new.cast(ENV.fetch('PAPER_MODE', nil))
  def exec_enabled? = ActiveModel::Type::Boolean.new.cast(ENV.fetch('EXECUTE_ORDERS', nil))
end
