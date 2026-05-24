# DEPRECATED

This repo is archived. Do not use or extend.

**Replaced by:** [`algo_scalper_api`](../algo_scalper_api)

## Why

`algo_scalper_api` is the active intraday scalper — it has a full production stack including WebSocket hub, event bus, SMC entry engine, risk manager, exit engine, and live position tracking. This repo has had no meaningful commits in 5+ months and its architecture was superseded.

## What lives where now

| Concern | Active repo |
|---|---|
| Live WebSocket feed | `algo_scalper_api` → `services/live/` |
| Entry signals (SMC/BOS) | `algo_scalper_api` → `services/entries/` |
| Risk management | `algo_scalper_api` → `services/live/risk_manager_service.rb` |
| Exit engine | `algo_scalper_api` → `services/live/exit_engine.rb` |
| TradingView webhooks | `algo_trading_api` → `controllers/webhooks/` |

Deprecated: 2026-03-01
