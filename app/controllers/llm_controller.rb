class LlmController < ApplicationController
  before_action :auth!

  def funds
    # replace with your real funds reader
    render json: { available: Funds::Reader.available_cash }
  end

  def positions
    render json: Positions::Reader.open_positions
  end

  def orders
    render json: Orders::Reader.order_book
  end

  def spot
    sym = params.require(:underlying)
    render json: { symbol: sym, spot: Market::SpotFetcher.call(symbol: sym).to_f }
  end

  def quote
    sid = params.require(:securityId).to_i
    q = Quotes::Reader.fetch(security_id: sid)
    render json: { securityId: sid, ltp: q[:ltp].to_f }
  end

  def option_chain
    u = params.require(:underlying)
    e = params.require(:expiry)
    chain = Option::ChainAnalyzer.new(underlying: u, expiry: e).build
    render json: chain
  end

  # ---- Execution endpoints used by MCP tool calls ----
  def place_bracket_order
    return render json: { dry_run: true, note: "paper or execution disabled" } if paper? || !exec_enabled?

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

  def paper? = ActiveModel::Type::Boolean.new.cast(ENV['PAPER_MODE'])
  def exec_enabled? = ActiveModel::Type::Boolean.new.cast(ENV['EXECUTE_ORDERS'])

  def auth!
    head :unauthorized unless request.headers['X-API-KEY'] == ENV['LLM_API_KEY']
  end
end
