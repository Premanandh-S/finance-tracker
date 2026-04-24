# frozen_string_literal: true

Rails.application.configure do
  # --- Reloading & Caching ---
  config.enable_reloading = true
  config.eager_load = false
  config.consider_all_requests_local = true

  # --- Database ---
  config.active_record.migration_error = :page_load
  config.active_record.verbose_query_logs = true

  # --- Logging ---
  config.log_level = :debug
  config.log_tags = [:request_id]
  config.logger = ActiveSupport::TaggedLogging.new(ActiveSupport::Logger.new($stdout))

  # --- Caching (disabled by default in dev) ---
  config.action_controller.perform_caching = false
  config.cache_store = :null_store

  # --- Deprecation warnings ---
  config.active_support.deprecation = :log
  config.active_support.disallowed_deprecation = :raise
  config.active_support.disallowed_deprecation_warnings = []

  # --- CORS ---
  # Allows the React dev server (localhost:5173) to call the Rails API.
  # Configured via rack-cors in config/initializers/cors.rb.

  # --- Action Mailer (letter_opener_web in dev — view emails at /letter_opener) ---
  config.action_mailer.delivery_method = :letter_opener_web
  config.action_mailer.perform_deliveries = true
  config.action_mailer.raise_delivery_errors = false
  config.action_mailer.perform_caching = false
  config.action_mailer.default_url_options = { host: "localhost", port: 3000 }
end
