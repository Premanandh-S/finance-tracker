# frozen_string_literal: true

module PensionInstruments
  # Handles create, update, and destroy operations for {PensionContribution} records
  # nested under a {PensionInstrument}.
  #
  # All actions require a valid JWT Bearer token. Business logic is delegated to
  # {Pensions::PensionManager}. The response for create and update is the full
  # updated instrument detail hash (including all contributions).
  #
  # @example Authenticated create request
  #   POST /pension_instruments/1/pension_contributions
  #   Authorization: Bearer <token>
  #   { "contribution_date": "2024-04-01", "amount": 180000, "contributor_type": "employee" }
  class PensionContributionsController < ApplicationController
    before_action :authenticate_user!

    # POST /pension_instruments/:pension_instrument_id/pension_contributions
    #
    # Adds a new contribution to a pension instrument. Returns the full updated
    # instrument detail including all contributions.
    #
    # @return [void] renders 201 with updated instrument detail, 422 on validation failure,
    #   or 404 when the instrument is not found
    def create
      result = Pensions::PensionManager.add_contribution(
        user:          current_user,
        instrument_id: params[:pension_instrument_id],
        params:        contribution_params.to_h.deep_symbolize_keys
      )
      render json: result, status: :created
    rescue Pensions::PensionManager::NotFoundError
      render_not_found
    rescue Pensions::PensionManager::ValidationError => e
      render_validation_error(e)
    end

    # PATCH /pension_instruments/:pension_instrument_id/pension_contributions/:id
    #
    # Updates an existing contribution on a pension instrument. Returns the full
    # updated instrument detail including all contributions.
    #
    # @return [void] renders 200 with updated instrument detail, 422 on validation failure,
    #   or 404 when the instrument or contribution is not found
    def update
      result = Pensions::PensionManager.update_contribution(
        user:            current_user,
        instrument_id:   params[:pension_instrument_id],
        contribution_id: params[:id],
        params:          contribution_params.to_h.deep_symbolize_keys
      )
      render json: result, status: :ok
    rescue Pensions::PensionManager::NotFoundError
      render_not_found
    rescue Pensions::PensionManager::ValidationError => e
      render_validation_error(e)
    end

    # DELETE /pension_instruments/:pension_instrument_id/pension_contributions/:id
    #
    # Removes a contribution from a pension instrument. Returns the full updated
    # instrument detail.
    #
    # @return [void] renders 200 with updated instrument detail, or 404 when not found
    def destroy
      result = Pensions::PensionManager.remove_contribution(
        user:            current_user,
        instrument_id:   params[:pension_instrument_id],
        contribution_id: params[:id]
      )
      render json: result, status: :ok
    rescue Pensions::PensionManager::NotFoundError
      render_not_found
    end

    private

    # Renders a 404 Not Found response for missing or inaccessible instruments or contributions.
    #
    # @return [void]
    def render_not_found
      render json: { error: "not_found", message: "Pension instrument not found" }, status: :not_found
    end

    # Renders a 422 Unprocessable Entity response for validation failures.
    #
    # @param e [Pensions::PensionManager::ValidationError] the raised error
    # @return [void]
    def render_validation_error(e)
      render json: {
        error:   "validation_failed",
        message: e.message,
        details: e.details
      }, status: :unprocessable_entity
    end

    # Strong parameters for pension contribution creation and update.
    #
    # @return [ActionController::Parameters] permitted contribution params
    def contribution_params
      params.permit(:contribution_date, :amount, :contributor_type)
    end
  end
end
