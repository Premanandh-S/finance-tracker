# frozen_string_literal: true

# CORS configuration for the Rails API.
# Allows the React frontend (Vite dev server on port 5173) to make requests
# to the Rails API in development. Tighten origins for production.

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins ENV.fetch("CORS_ORIGINS", "http://localhost:5173")

    resource "*",
      headers: :any,
      methods: %i[get post put patch delete options head],
      expose: ["Authorization"],
      credentials: true
  end
end
