# frozen_string_literal: true

# Handles CRUD operations for {Loan} records.
#
# All actions require a valid JWT Bearer token. Business logic is delegated to
# {Loans::LoanManager}. Computation errors from {Loans::PaymentCalculator} are
# caught and mapped to 422 responses.
#
# @example Authenticated request
#   GET /loans
#   Authorization: Bearer <token>
class LoansController < ApplicationController
  before_action :authenticate_user!

  # GET /loans
  #
  # Returns all loans belonging to the authenticated user, each decorated with
  # computed +next_payment_date+ and +payoff_date+.
  #
  # @return [void] renders 200 with an array of loan hashes
  def index
    loans = Loans::LoanManager.list(user: current_user)
    render json: loans, status: :ok
  rescue Loans::PaymentCalculator::NonConvergingLoanError => e
    render_non_converging_error(e)
  end

  # GET /loans/:id
  #
  # Returns full detail for a single loan, including the amortisation schedule.
  #
  # @return [void] renders 200 with loan detail hash, or 404 when not found
  def show
    loan = Loans::LoanManager.show(user: current_user, loan_id: params[:id])
    render json: loan, status: :ok
  rescue Loans::LoanManager::NotFoundError
    render_not_found
  rescue Loans::PaymentCalculator::NonConvergingLoanError => e
    render_non_converging_error(e)
  end

  # POST /loans
  #
  # Creates a new loan for the authenticated user.
  #
  # @return [void] renders 201 with the created loan, or 422 on validation failure
  def create
    loan = Loans::LoanManager.create(user: current_user, params: loan_params.to_h.deep_symbolize_keys)
    render json: loan, status: :created
  rescue Loans::LoanManager::ValidationError => e
    render_validation_error(e)
  rescue Loans::PaymentCalculator::NonConvergingLoanError => e
    render_non_converging_error(e)
  end

  # PATCH /loans/:id
  #
  # Updates an existing loan belonging to the authenticated user.
  #
  # @return [void] renders 200 with the updated loan, 404 when not found, or 422 on validation failure
  def update
    loan = Loans::LoanManager.update(
      user:    current_user,
      loan_id: params[:id],
      params:  loan_params.to_h.deep_symbolize_keys
    )
    render json: loan, status: :ok
  rescue Loans::LoanManager::NotFoundError
    render_not_found
  rescue Loans::LoanManager::ValidationError => e
    render_validation_error(e)
  rescue Loans::PaymentCalculator::NonConvergingLoanError => e
    render_non_converging_error(e)
  end

  # DELETE /loans/:id
  #
  # Permanently deletes a loan and all its associated interest rate periods.
  #
  # @return [void] renders 204 No Content on success, or 404 when not found
  def destroy
    Loans::LoanManager.destroy(user: current_user, loan_id: params[:id])
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

  # Renders a 422 Unprocessable Entity response for validation failures.
  #
  # @param e [Loans::LoanManager::ValidationError] the raised error
  # @return [void]
  def render_validation_error(e)
    render json: {
      error:   "validation_failed",
      message: e.message,
      details: e.details
    }, status: :unprocessable_entity
  end

  # Renders a 422 Unprocessable Entity response for non-converging loan calculations.
  #
  # @param e [Loans::PaymentCalculator::NonConvergingLoanError] the raised error
  # @return [void]
  def render_non_converging_error(e)
    render json: { error: "non_converging_loan", message: e.message }, status: :unprocessable_entity
  end

  # Strong parameters for loan creation and update.
  #
  # @return [ActionController::Parameters] permitted loan params
  def loan_params
    params.permit(
      :institution_name,
      :loan_identifier,
      :outstanding_balance,
      :annual_interest_rate,
      :interest_rate_type,
      :monthly_payment,
      :payment_due_day,
      interest_rate_periods: %i[id start_date end_date annual_interest_rate]
    )
  end
end
