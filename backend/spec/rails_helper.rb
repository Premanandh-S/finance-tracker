# frozen_string_literal: true

require "spec_helper"
ENV["RAILS_ENV"] ||= "test"
ENV["SECRET_KEY_BASE"] ||= "test_secret_key_base_for_testing_only_do_not_use_in_production_abc123def456"
require_relative "../config/environment"

require "rspec/rails"
require "database_cleaner/active_record"

RSpec.configure do |config|
  config.use_transactional_fixtures = false

  config.before(:suite) do
    DatabaseCleaner.strategy = :truncation
    DatabaseCleaner.clean_with(:truncation)
  end

  config.before(:each) do
    DatabaseCleaner.start
  end

  config.after(:each) do
    DatabaseCleaner.clean
  end

  config.include ActiveSupport::Testing::TimeHelpers
end
