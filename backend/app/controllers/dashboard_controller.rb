# frozen_string_literal: true

# Handles the aggregated dashboard endpoint.
#
# Authenticates the request and delegates entirely to
# {Dashboard::DashboardAggregator} to assemble the full portfolio payload.
class DashboardController < ApplicationController
  before_action :authenticate_user!

  # GET /dashboard
  #
  # Returns the full dashboard payload for the authenticated user, containing
  # summaries for all four financial domains: savings, loans, insurance, and
  # pensions.
  #
  # @return [void] renders JSON with status 200
  def show
    payload = Dashboard::DashboardAggregator.call(user: current_user)
    render json: payload, status: :ok
  end
end
