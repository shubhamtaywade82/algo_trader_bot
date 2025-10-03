# Repository Guidelines

## Project Structure & Module Organization
The Rails backbone lives under `app/`, with `scalpers/` split into `base`, `stocks`, and `options` engines, and services such as `services/strategies` and `services/option/chain_analyzer.rb`. Models (`app/models`) define instruments and candle series; background runners reside in `bin/` (`stock_scalper`, `options_scalper`) and `runners/algo_runner.rb`. Configuration files stay in `config/`, database migrations in `db/`, and documentation assets in `docs/`. Specs sit in `spec/`, mirroring the service structure so new code lands alongside its tests.

## Build, Test, and Development Commands
Run `bundle install` after pulling new dependencies. Initialize local databases with `rails db:prepare` (or `rails db:create db:migrate` on first setup). Execute the full bot loop via `rails runner 'AlgoRunner.execute_all'`. Use `bundle exec ruby bin/stock_scalper` or `bundle exec ruby bin/options_scalper` for lane-specific runs. `bundle exec rake "ws:check[IDX_I,13,quote,15]"` helps validate DhanHQ WebSocket connectivity.

## Coding Style & Naming Conventions
Follow Ruby's two-space indentation and prefer single quotes unless interpolation is needed. Service objects live under `Services::` namespaces; keep filenames snake_case (`supertrend_strategy.rb`) and classes CamelCase. Apply RuboCop before commits with `bundle exec rubocop`, ensuring any rule suppressions are justified inline.

## Testing Guidelines
RSpec drives coverage; place new specs beneath `spec/` mirroring the code path (`spec/services/strategies/..._spec.rb`). Name examples with clear behavior descriptions (`describe '#execute' do ...`). Run the full suite using `bundle exec rspec` before opening a PR, and add focused specs for every new strategy, scaler, or integration branch. Keep fixtures lightweight and prefer doubles for external APIs.

## Commit & Pull Request Guidelines
Use short, imperative commit subjects similar to the existing history (`Fix AutoPilot OHLC fetch with API guard`). Group related changes into single commits and reference issue IDs when relevant. Pull requests should summarize intent, list verification steps (tests, manual runs), and include screenshots or logs for trading flows when behavior changes. Request review from a maintainer and ensure CI passes before merging.

## Environment & Secrets
Store DhanHQ and Telegram credentials in local `.env` files or Rails credentials, never in version control. Document any new env vars in `README.md` and provide safe defaults or stubs for test runs. Rotate keys promptly if accidentally exposed.
