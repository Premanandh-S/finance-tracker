# frozen_string_literal: true

# Handles CRUD operations for {PensionInstrument} records.
#
# All actions require a valid JWT Bearer token. Business logic is delegated to
# {Pensions::PensionManager}.
#
# @example Authenticated request
#   GET /pension_instruments
#   Authorization: Bearer <token>
class PensionInstrumentsController < ApplicationController
  before_action :authenticate_user!

  # GET /pension_instruments
  #
  # Returns all pension instruments belonging to the authenticated user, each
  # decorated with a computed +total_corpus+.
  #
  # @return [void] renders 200 with an array of pension instrument hashes
  def index
    instruments = Pensions::PensionManager.list(user: current_user)
    render json: instruments, status: :ok
  end

  # GET /pension_instruments/:id
  #
  # Returns full detail for a single pension instrument, including the computed
  # total corpus and contributions ordered by date descending.
  #
  # @return [void] renders 200 with instrument detail hash, or 404 when not found
  def show
    instrument = Pensions::PensionManager.show(user: current_user, instrument_id: params[:id])
    render json: instrument, status: :ok
  rescue Pensions::PensionManager::NotFoundError
    render_not_found
  end

  # POST /pension_instruments
  #
  # Creates a new pension instrument for the authenticated user.
  #
  # @return [void] renders 201 with the created instrument, or 422 on validation failure
  def create
    instrument = Pensions::PensionManager.create(
      user:   current_user,
      params: pension_instrument_params.to_h.deep_symbolize_keys
    )
    render json: instrument, status: :created
  rescue Pensions::PensionManager::ValidationError => e
    render_validation_error(e)
  end

  # PATCH /pension_instruments/:id
  #
  # Updates an existing pension instrument belonging to the authenticated user.
  #
  # @return [void] renders 200 with the updated instrument, 404 when not found,
  #   or 422 on validation failure
  def update
    instrument = Pensions::PensionManager.update(
      user:          current_user,
      instrument_id: params[:id],
      params:        pension_instrument_params.to_h.deep_symbolize_keys
    )
    render json: instrument, status: :ok
  rescue Pensions::PensionManager::NotFoundError
    render_not_found
  rescue Pensions::PensionManager::ValidationError => e
    render_validation_error(e)
  end

  # DELETE /pension_instruments/:id
  #
  # Permanently deletes a pension instrument and all its associated contributions.
  #
  # @return [void] renders 204 No Content on success, or 404 when not found
  def destroy
    Pensions::PensionManager.destroy(user: current_user, instrument_id: params[:id])
    head :no_content
  rescue Pensions::PensionManager::NotFoundError
    render_not_found
  end

  private

  # Renders a 404 Not Found response for missing or inaccessible pension instruments.
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

  # Strong parameters for pension instrument creation and update.
  #
  # @return [ActionController::Parameters] permitted pension instrument params
  def pension_instrument_params
    params.permit(
      :institution_name,
      :pension_identifier,
      :pension_type,
      :monthly_contribution_amount,
      :contribution_start_date,
      :maturity_date,
      :notes
    )
  end
end
