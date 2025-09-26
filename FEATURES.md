# AlgoTrader Bot Features

## Market Data & Instrument Management

- **Streaming market data hub** – `Live::WsHub` manages DhanHQ WebSocket sessions, throttles subscriptions, and forwards ticks to downstream handlers such as the execution supervisor.
- **Tick and quote cache** – `Live::TickCache` and `Live::Quote` supply low-latency LTP/bid-ask data with REST fallbacks when streaming data is unavailable.
- **Scheduled OHLC ingestion** – `Bars::FetchLoop` keeps per-symbol candle series fresh, while `CandleSeries` normalises broker payloads, exposes RSI/MACD/ATR/Bollinger helpers, and provides swing/liquidity pattern checks.
- **Multi-timeframe resampling** – `Mtf::SeriesLoader` and `Mtf::Resampler` promote 5m feeds into 15m/1h/4h aggregates for higher timeframe confirmation.
- **Instrument & derivative import** – `InstrumentsImporter` fetches the Dhan scrip master with a 24h cache, splits instruments vs derivatives, and bulk upserts them for fast lookup.
- **Option chain accessors** – `Instrument#fetch_option_chain` filters unusable strikes and exposes expiry lists to the rest of the stack.

## Strategy & Signal Engine

- **Holy Grail signal stack** – `Indicators::HolyGrail` fuses EMA alignment, MACD, RSI, ATR, and configurable ADX gates into a single bias/momentum verdict and go/no-go decision.
- **Technical indicator toolkit** – `Indicators::Calculator` plus the indicator-rich `CandleSeries` support RSI/ADX/MACD/Supertrend/Bollinger/Donchian calculations for custom strategies.
- **Regime detection** – `Regime::ChopDetector` blocks trades in low-ADX or narrow-range conditions using ATR contraction, VWAP crossings, and NR signals.

## Option Selection & Analysis

- **Advanced chain scoring** – `Option::ChainAnalyzer` ranks strikes with delta bands, IV rank limits, theta decay timing, liquidity checks, greeks weighting, skew/IV z-scores, and momentum boosts.
- **Derivative resolution** – `Derivatives::Picker` ties analyzer output to actual tradable contracts, computes IV rank, loads historical candles, and returns a ready-to-trade derivative object.
- **Legacy compatibility facade** – `Options::ChainAnalyzer` wraps the new picker so older callers still receive the classic strike hash (bid/ask/spread/lot size).

## Execution & Order Lifecycle

- **Super order construction** – `Orders::SuperParamsBuilder` converts strategy intent into DhanHQ SuperOrder payloads with tick-sized prices, trail jumps, and product routing.
- **Idempotent order placement** – `Orders::Executor` guards entries with advisory locks, caches broker responses, bumps in-memory position state, and honours risk toggles.
- **Live position supervision** – `Execution::Supervisor` reconciles broker positions, subscribes them on the WebSocket feed, and spawns `Execution::PositionTracker` instances to trail stops, arm breakeven, enforce stale-win exits, and keep super-order brackets synced.
- **Protective exit utilities** – `Execution::PositionGuard`, `Exits::MicroTP`, `Exits::AlignmentGuard`, and `Orders::SuperModifier` tighten brackets, micro-manage TP/SL under chop, and flatten exposure when trend alignment breaks.
- **Order closing helpers** – `Orders::Manager` cancels super orders or fires market exits, while `Orders::Closer` offers simple cancellation by client reference.

## Risk & Capital Management

- **Capital budgeting** – `Execution::Budget` caps deployable capital per trade, tracks day PnL, and exposes a kill switch once the max day loss is reached.
- **Risk guardrails** – `Risk::Guard` enforces global enable/disable flags, tick staleness checks, per-trade risk, trade count ceilings, and daily drawdown limits via cached broker state.
- **Position sizing** – `Sizing::Capital` and `Sizing.qty_for_rupees_risk` translate allocation percentages or rupee risk into lot counts with slippage buffers.
- **Exit policy tuning** – `Execution::RiskPolicy`, `Risk::ToSuperParams`, and `Risk::ScalpParams` centralise SL/TP/trailing parameters for different playbooks.
- **Portfolio-wide safety** – `Runner::PositionsLoop` watches live PnL, applies micro take-profit logic, and forces a hard flat plus trading kill-switch when the daily cap is breached.

## Automation & Scheduling

- **AutoPilot orchestrator** – `Runner::AutoPilot` runs normal, scalp, or demo modes, enforces trading windows, screens trend/ADX gates, selects CE/PE legs, and wires risk checks before placing super orders.
- **Background loops** – `Runner::PositionsLoop` manages open trades, `Bars::FetchLoop` maintains candles, and `Runner::RecentSignals` suppresses duplicate alerts.
- **Task automation** – Rake tasks (`lib/tasks/trader.rake`, `lib/tasks/import_instruments.rake`) start/stop strategy + position loops and refresh the instrument universe.

## Integrations & Notifications

- **Telegram alerting** – `ApplicationService` helpers plus `TelegramNotifier` emit step-by-step, success, and failure notifications, and support chat actions for operator feedback.
- **AI commentary hook** – `Openai::BehaviourExplainer` packages option chain snapshots into GPT prompts and returns human-readable trade rationale.
- **DhanHQ API coverage** – Instruments, orders, positions, funds, historical data, and option chains all run through the official client wrappers in a consistent manner.

## State, Reconciliation & Observability

- **In-memory state caches** – `State::OrderCache` and `State::PositionCache` keep the bot’s view of broker orders/positions, emit append-only NDJSON logs via `State::Events`, and support replay on restart.
- **Broker & portfolio sync** – `Broker::ReconcileLight` and `Portfolio::Sync` reconcile holdings, positions, and super order status to prevent drift from manual actions.
- **Configurable runtime settings** – The `Setting` model exposes cached key/value toggles (e.g., kill switch, risk budgets), while `MarketCalendar` centralises trading-day awareness for schedulers.
