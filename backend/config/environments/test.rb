# frozen_string_literal: true

Rails.application.configure do
  config.eager_load = false
  config.cache_classes = true
  config.action_dispatch.show_exceptions = :none
  config.active_support.deprecation = :stderr
  config.active_record.migration_error = :page_load
  config.active_record.verbose_query_logs = false
end
