# frozen_string_literal: true

require 'simplecov'
require 'simplecov-json'

SimpleCov.start 'rails' do
  add_filter '/spec/'
  add_filter '/config/'
  add_filter '/vendor/'

  add_group 'Services', 'app/services'
  add_group 'Controllers', 'app/controllers'
  add_group 'Models', 'app/models'
  add_group 'Strategies', 'app/strategies'
  add_group 'AI', 'app/services/ai'
  add_group 'Trading', 'app/services/trading'
  add_group 'Position', 'app/services/position'
  add_group 'Risk', 'app/services/risk'
  add_group 'Notifications', 'app/services/notifications'

  minimum_coverage 90
  maximum_coverage_drop 5
end

SimpleCov.formatters = [
  SimpleCov::Formatter::HTMLFormatter,
  SimpleCov::Formatter::JSONFormatter
]
