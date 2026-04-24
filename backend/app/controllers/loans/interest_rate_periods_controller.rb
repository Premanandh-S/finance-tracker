# frozen_string_literal: true

module Loans
  # Handles create, update, and destroy operations for {InterestRatePeriod} records
  # nested under a {Loan}.
  #
  # All actions require a valid JWT Bearer token. Business logic is delegated to
  # {Loans::LoanManager}. The response for create and update is the full updated
  # loan detail hash (including the recalculated amortisation schedule).
  #
  # @example Authenticated create request
  #   POST /loans/1/interest_rate_periods
  #   Authorization: Bearer <token>
  #   { "start_date": "2024-01-01", "annual_interest_rate": 9.5 }
  class InterestRatePeriodsController < ApplicationController
    before_action :authenticate_user!

    # POST /loans/:loan_id/interest_rate_periods
    #
    # Adds a new interest rate period to a floating-rate loan. Returns the full
    # updated loan detail including the recalculated amortisation schedule.
    #
    # @return [void] renders 201 with updated loan detail, 422 on validation failure,
    #   or 404 when the loan is not found
    def create
      result = Loans::LoanManager.add_or_update_rate_period(
        user:    current_user,
        loan_id: params[:loan_id],
        params:  rate_period_params.to_h.deep_symbolize_keys
      )
      render json: result, status: :created
    rescue Loans::LoanManager::ValidationError => e
      render_invalid_operation_error(e)
    rescue Loans::LoanManager::NotFoundError
      render_not_found
    end

    # PATCH /loans/:loan_id/interest_rate_periods/:id
    #
    # Updates an existing interest rate period on a floating-rate loan. Returns the
    # full updated loan detail including the recalculated amortisation schedule.
    #
    # @return [void] renders 200 with updated loan detail, 422 on validation failure,
    #   or 404 when the loan or period is not found
    def update
      result = Loans::LoanManager.add_or_update_rate_period(
        user:    current_user,
        loan_id: params[:loan_id],
        params:  rate_period_params.to_h.deep_symbolize_keys.merge(id: params[:id])
      )
      render json: result, status: :ok
    rescue Loans::LoanManager::ValidationError => e
      render_invalid_operation_error(e)
    rescue Loans::LoanManager::NotFoundError
      render_not_found
    end

    # DELETE /loans/:loan_id/interest_rate_periods/:id
    #
    # Removes an interest rate period from a loan. The loan must belong to the
    # authenticated user and the period must belong to that loan.
    #
    # @return [void] renders 204 No Content on success, or 404 when not found
    def destroy
      loan = current_user.loans.find_by(id: params[:loan_id])
      raise Loans::LoanManager::NotFoundError, "Loan not found" unless loan

      period = loan.interest_rate_periods.find_by(id: params[:id])
      raise Loans::LoanManager::NotFoundError, "Interest rate period not found" unless period

      period.destroy!
      head :no_content
    rescue Loans::LoanManager::NotFoundError
      render_not_found
    end

    private

    # Renders a 404 Not Found response for missing or inaccessible loans.
    #
    # @return [void]
    def render_not_found
      render json: { error: "not_found", message: "Loan not found" }, status: :not_found
    end

    # Renders a 422 Unprocessable Entity response for invalid operation errors
    # (e.g. attempting to add a rate period to a fixed-rate loan) or validation
    # failures on the rate period itself.
    #
    # @param e [Loans::LoanManager::ValidationError] the raised error
    # @return [void]
    def render_invalid_operation_error(e)
      render json: {
        error:   "invalid_operation",
        message: e.message,
        details: e.details
      }, status: :unprocessable_entity
    end

    # Strong parameters for interest rate period create and update.
    #
    # @return [ActionController::Parameters] permitted rate period params
    def rate_period_params
      params.permit(:start_date, :end_date, :annual_interest_rate)
    end
  end
end
