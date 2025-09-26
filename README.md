# 📈 AlgoTradingBot (Rails-based)

An advanced, modular, event-driven algorithmic trading bot for **Options Buying** using **DhanHQ APIs**, **technical indicators**, **Telegram alerts**, and **AI-assisted strategy reasoning**.

Built in **Ruby on Rails**, this bot is designed to:

* Identify CE/PE entries using technical + price action strategies
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
* Smart CE/PE selection per signal
* Auto-skip if no signal or no affordable strike
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
├── models/
│   ├── instrument.rb
│   ├── concerns/instrument_helpers.rb
│   ├── candle.rb
│   └── candle_series.rb
│
├── services/
│   ├── application_service.rb
│   ├── indicators/
│   │   └── calculator.rb
│   ├── strategies/
│   │   ├── basic_trend_strategy.rb
│   │   ├── supertrend_strategy.rb
│   │   ├── price_action_strategy.rb
│   │   └── smart_money_concepts.rb
│   ├── option/
│   │   └── chain_analyzer.rb
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
