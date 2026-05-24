# frozen_string_literal: true

module Scalpers; end unless defined?(Scalpers)

Rails.autoloaders.main.push_dir(Rails.root.join('app/scalpers'), namespace: Scalpers)
