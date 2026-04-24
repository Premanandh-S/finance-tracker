# frozen_string_literal: true

# Handles CRUD operations for {SavingsInstrument} records.
#
# All actions require a valid JWT Bearer token. Business logic is delegated to
# {Savings::SavingsManager}.
#
# @example Authenticated request
#   GET /savings_instruments
#   Authorization: Bearer <token>
class SavingsInstrumentsController < ApplicationController
  before_action :authenticate_user!

  # GET /savings_instruments
  #
  # Returns all savings instruments belonging to the authenticated user, each
  # decorated with a computed +maturity_value+.
  #
  # @return [void] renders 200 with an array of savings instrument hashes
  def index
    instruments = Savings::SavingsManager.list(user: current_user)
    render json: instruments, status: :ok
  end

  # GET /savings_instruments/:id
  #
  # Returns full detail for a single savings instrument, including the computed
  # maturity value and payment schedule.
  #
  # @return [void] renders 200 with instrument detail hash, or 404 when not found
  def show
    instrument = Savings::SavingsManager.show(user: current_user, instrument_id: params[:id])
    render json: instrument, status: :ok
  rescue Savings::SavingsManager::NotFoundError
    render_not_found
  end

  # POST /savings_instruments
  #
  # Creates a new savings instrument for the authenticated user.
  #
  # @return [void] renders 201 with the created instrument, or 422 on validation failure
  def create
    instrument = Savings::SavingsManager.create(
      user:   current_user,
      params: savings_instrument_params.to_h.deep_symbolize_keys
    )
    render json: instrument, status: :created
  rescue Savings::SavingsManager::ValidationError => e
    render_validation_error(e)
  end

  # PATCH /savings_instruments/:id
  #
  # Updates an existing savings instrument belonging to the authenticated user.
  #
  # @return [void] renders 200 with the updated instrument, 404 when not found,
  #   or 422 on validation failure
  def update
    instrument = Savings::SavingsManager.update(
      user:          current_user,
      instrument_id: params[:id],
      params:        savings_instrument_params.to_h.deep_symbolize_keys
    )
    render json: instrument, status: :ok
  rescue Savings::SavingsManager::NotFoundError
    render_not_found
  rescue Savings::SavingsManager::ValidationError => e
    render_validation_error(e)
  end

  # DELETE /savings_instruments/:id
  #
  # Permanently deletes a savings instrument belonging to the authenticated user.
  #
  # @return [void] renders 204 No Content on success, or 404 when not found
  def destroy
    Savings::SavingsManager.destroy(user: current_user, instrument_id: params[:id])
    head :no_content
  rescue Savings::SavingsManager::NotFoundError
    render_not_found
  end

  private

  # Renders a 404 Not Found response for missing or inaccessible savings instruments.
  #
  # @return [void]
  def render_not_found
    render json: { error: "not_found", message: "Savings instrument not found" }, status: :not_found
  end

  # Renders a 422 Unprocessable Entity response for validation failures.
  #
  # @param e [Savings::SavingsManager::ValidationError] the raised error
  # @return [void]
  def render_validation_error(e)
    render json: {
      error:   "validation_failed",
      message: e.message,
      details: e.details
    }, status: :unprocessable_entity
  end

  # Strong parameters for savings instrument creation and update.
  #
  # @return [ActionController::Parameters] permitted savings instrument params
  def savings_instrument_params
    params.permit(
      :institution_name,
      :savings_identifier,
      :savings_type,
      :principal_amount,
      :annual_interest_rate,
      :contribution_frequency,
      :start_date,
      :maturity_date,
      :recurring_amount,
      :notes
    )
  end
end
