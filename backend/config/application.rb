# frozen_string_literal: true

require_relative "boot"
require "rails/all"

Bundler.require(*Rails.groups)

module AuthApp
  class Application < Rails::Application
    config.load_defaults 8.0
    config.api_only = true

    # Not using Active Storage — suppress image_processing warning
    config.active_storage.variant_processor = :disabled
  end
end
