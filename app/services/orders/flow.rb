module Orders
  class Flow
    def self.place_from_plan(plan)
      # 1) Resolve instrument (use your DB or Master Script, whichever your app uses)
      inst = Instruments::Resolver.from_master_csv(
        underlying: plan['underlying'],
        expiry_kind: plan['expiry_kind'],
        option_type: plan['direction'],
        strike_selector: plan['strike_selector']
      )

      # 2) Affordability & lot sizing
      funds = Funds::Reader.available_cash
      q     = Quotes::Reader.fetch(security_id: inst.security_id)
      ltp   = q[:ltp].to_f
      lot   = inst.lot_size
      max_rupees = funds * plan.dig('risk', 'allocation_pct').to_f
      lots = (max_rupees / (ltp * lot)).floor
      raise 'Not affordable' if lots < 1

      # 3) Place bracket (controller guards paper/live)
      Execution::OrderExecutor.place_bracket(
        security_id: inst.security_id,
        quantity: lots * lot,
        sl_pct: plan.dig('risk', 'sl_pct'),
        tp_pct: plan.dig('risk', 'tp_pct')
      )

      Trail::Manager.attach(inst.security_id, trail_tick: plan.dig('risk', 'trail_tick'))
      Journal.enter(plan: plan, instrument: inst, qty: lots * lot)
    end
  end
end
