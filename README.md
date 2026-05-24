> **DEPRECATED** — This repo is archived. Replaced by [`algo_scalper_api`](../algo_scalper_api). See [DEPRECATED.md](./DEPRECATED.md).

# 📈 AlgoTradingBot (Rails-based)

An advanced, modular, event-driven algorithmic trading bot for **Options Buying** and **equity scalping** using **DhanHQ APIs**, **technical indicators**, **Telegram alerts**, and **AI-assisted strategy reasoning**.

Built in **Ruby on Rails**, this bot is designed to:

* Identify CE/PE entries using technical + price action strategies
* Run a two-lane intraday scalper (stocks + index options) on the same shared core
* Analyze option chains with IV, OI, Greeks, and smart filters
* Place Super Orders (SL/TP/Trailing) using DhanHQ
* Send real-time trade updates via Telegram

---

## 🚀 Features

### 🔍 Strategy & Signal Engine

* Modular Strategy Layer with plug-n-play classes

  * `BasicTrendStrategy`
  * `SupertrendStrategy`
  * `PriceActionStrategy`
  * `SmartMoneyConcepts` (Breaker Blocks, Mitigation Zones)
* `CandleSeries` and `Candle` model for clean time-series logic
* Indicator layer powered by `ruby_technical_analysis` (RSI, ADX, MACD, ATR)
* Supertrend and ATR-based trailing stops
* Signal Gating: RSI < 30 + ADX > 20, Breaker Blocks, Trend Confirmation

### 🧠 Option Chain Analyzer

* ATM/ITM/OTM range filtering
* Greeks filtering (delta, gamma, theta, vega)
* OI, IV, Volume ranking
* Bid-ask spread and liquidity checks
* Scoring mechanism per strike
* Adaptive strategy thresholds

### 📤 Execution Engine

* Real-time LTP fetch via DhanHQ
* Capital allocation logic (30% default)
* Quantity sizing per lot
* Super Order builder (entry + SL + TP + trailing)
* Order placement via DhanHQ API
* Handles both CE and PE entries and exits

### 📡 Telegram Alerts

* Live notifications at every stage:

  * Strategy signal
  * Option chain result summary
  * Order placement
  * Errors / Skips
* `notify_step`, `notify_success`, `notify_failure` built into `ApplicationService`

### 🔁 Automation & Scheduling

* `AlgoRunner` executes all watchlisted instruments every 5 minutes
* Dedicated two-lane scalper runners (`bin/stock_scalper`, `bin/options_scalper`) backed by a shared engine
* Smart CE/PE selection per signal and liquidity-aware chain picking
* Auto-skip if no signal, liquidity fails, or rate limits kick in
* Sidekiq / Whenever-compatible runners

### 🧠 AI Integration (Optional)

* Planned OpenAI-based trade analysis pipeline

  * Converts SMC, price action, volume context into JSON prompt
  * Returns: "Should you enter this trade?" explanation
  * Future: DhanHQ execution based on AI confirmation

---

## 🛠️ Setup Instructions

### Prerequisites

* Ruby >= 3.2
* Rails >= 7.1
* Redis (for Sidekiq, optional)
* PostgreSQL or SQLite
* Environment variables:

  * `CLIENT_ID`, `ACCESS_TOKEN` (DhanHQ API credentials)
  * `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID`

### 1. Clone & Install

```bash
git clone https://github.com/yourname/algo_trading_bot.git
cd algo_trading_bot
bundle install
rails db:create db:migrate
```

### 2. Instrument Setup

Add instruments in DB with:

```ruby
Instrument.create!(symbol: 'NIFTY', segment: 'index', exchange: 'NSE', watch_type: :options_buying)
Instrument.create!(symbol: 'BANKNIFTY', segment: 'index', exchange: 'NSE', watch_type: :options_buying)
Instrument.create!(symbol: 'RELIANCE', segment: 'equity', exchange: 'NSE', watch_type: :options_buying)
```

### 3. Run Manually

```bash
rails runner 'AlgoRunner.execute_all'
```

### 3a. Launch the Intraday Scalpers

Both scalpers share the same data/risk core. Edit the YAML config or provide your own via `SCALPER_CONFIG`.

```bash
bundle exec ruby bin/stock_scalper      # Equity scalper lane
bundle exec ruby bin/options_scalper    # Index options scalper lane
```

Each launcher spins up a Dhan WebSocket feed, the staggered 1m/5m bar fetch loop, and the lane-specific runner.

#### Capability Matrix

| Lane   | Universe                          | Direction     | Order Type          | Sizing                              | Default SL / TP |
|--------|-----------------------------------|---------------|---------------------|-------------------------------------|-----------------|
| Stocks | Watchlisted NSE equities          | Long & Short  | Bracket (market)    | ≤1% risk per trade, max 5× leverage | ~1% / +2%       |
| Options | NIFTY/BANKNIFTY/SENSEX weekly ATM | CE/PE buying  | Bracket (market)    | ≤1% cash premium budget             | ~30% / +60%     |

The shared core covers the WebSocket feed → LTP cache, 1m/5m OHLC fetch → bars cache, the signal engine (Supertrend + BOS +
regime), guardrails (session/day-down/losers/cooldown), rate-limit token bucket with backoff, and base sizing helpers.

Lane-specific modules wire their own policy/sizer/executor logic on top:

* **Stocks** – spread filter, leverage-aware equity sizing, long/short bracket execution with ~1% SL / +2% TP targets.
* **Options** – direction → CE/PE mapping, liquidity-aware chain picker, premium-budget sizing, and 30%/60% SL/TP brackets.

### 3b. (Optional) Verify WebSocket Feed

Ensure `CLIENT_ID` and `ACCESS_TOKEN` are exported, then run:

```bash
bundle exec rake "ws:check[IDX_I,13,quote,15]"
```

This opens a short-lived DhanHQ WebSocket session, subscribes to NIFTY (`IDX_I`, security id `13`), and reports whether a tick arrives within 15 seconds. Override the defaults with `WS_CHECK_*` environment variables if you prefer not to pass rake arguments.

### 4. Schedule with Cron / Sidekiq

* Use Sidekiq job or `whenever` gem to schedule `AlgoRunner.execute_all` every 5 mins

---

## 📂 Code Structure

```
app/
├── scalpers/
│   ├── base/ (engine, risk profile, sizing, DI, shared runner)
│   ├── stocks/ (policy, sizer, executor, runner)
│   └── options/ (chain picker, policy, sizer, executor, runner)
├── models/
│   ├── instrument.rb
│   ├── concerns/instrument_helpers.rb
│   ├── candle.rb
│   └── candle_series.rb
│
├── services/
│   ├── application_service.rb
│   ├── bars/ (intraday fetch loop)
│   ├── indicators/
│   │   └── calculator.rb
│   ├── strategies/
│   │   ├── basic_trend_strategy.rb
│   │   ├── supertrend_strategy.rb
│   │   ├── price_action_strategy.rb
│   │   └── smart_money_concepts.rb
│   ├── option/
│   │   └── chain_analyzer.rb
│   ├── feed/runner.rb (Dhan WS glue)
│   ├── rate_limiter/ (token bucket + backoff)
│   ├── stores/ (LTP + bars caches for scalpers)
│   └── execution/
│       └── order_executor.rb
│
├── runners/
│   └── algo_runner.rb
│
└── notifiers/
    └── telegram_notifier.rb
```

---

## 📊 Logging & Debugging

* Logs are auto-tagged with service class
* Use `log_info`, `log_error` helpers
* Telegram message structure:

```
[Strategies::SupertrendStrategy] [SIGNAL]

🔹 Step: Signal Identified
...
```

---

## 🧪 Testing

* RSpec setup with mocks
* Option chain analyzer, strategy logic covered in spec
* Sample specs:

  * `spec/services/strategies/basic_trend_strategy_spec.rb`
  * `spec/services/option/chain_analyzer_spec.rb`

---

## ✨ Upcoming Features

* 🔍 Breaker Block, Mitigation Zone Detection (SMC)
* 📡 WebSocket LTP integration
* 📊 Trade Dashboard + PnL Tracker
* 🤖 OpenAI Trade Justification Assistant
* 📈 Multi-timeframe trend analyzer

---

## 📬 Telegram Commands (Planned)

* `/signal NIFTY` → Run strategy for NIFTY
* `/exit_all` → Force exit all positions
* `/summary` → Show open trades + status

---

## 👥 Contributing

1. Fork this repo
2. Add your feature in a new branch
3. Add specs and tests
4. Submit a PR 🚀

---

## 📄 License

MIT

---

## 🙌 Acknowledgements

* [DhanHQ API](https://docs.dhan.co)
* [ruby\_technical\_analysis gem](https://github.com/vinaysahni/ruby-technical-analysis)
* OpenAI for future GPT trade assist
