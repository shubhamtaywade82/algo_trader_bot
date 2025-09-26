# Autonomy Backlog

- [ ] Integrate `Sizing::Capital`/budget rules into `Runner::AutoPilot` so lot quantity reflects allocation, risk per trade, and account balance.
- [ ] Block duplicate entries by consulting `State::PositionCache` (or Dhan positions) before placing a new order; allow controlled scaling when signal strength warrants it.
- [ ] Ensure the intended live manager (`Execution::PositionGuard` or `Execution::Supervisor` + trackers) is booted consistently so every new leg is tracked and exited by policy.
- [ ] Build an orchestration entry point (job/runner) that starts the WS hub, reconciler, and AutoPilot with the correct roster automatically.
- [ ] Expand technical-analysis flow to detect “strong” signals and pass that context into sizing/scale-in logic.
- [ ] Harden AHLC polling: cache recent responses, add exponential backoff on API hiccups, and persist last-fetched timestamps per symbol for observability.
- [ ] Add automated tests covering the end-to-end trade loop (signal → picker → sizing → order placement guard).
- [ ] Expose a diagnostic command/task that surfaces overall system health (WS status, last option-chain fetch, risk budget remaining).
