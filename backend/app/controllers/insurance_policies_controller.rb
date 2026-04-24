# frozen_string_literal: true

# Handles CRUD operations for {InsurancePolicy} records.
#
# All actions require a valid JWT Bearer token. Business logic is delegated to
# {Insurance::InsuranceManager}.
#
# @example Authenticated request
#   GET /insurance_policies
#   Authorization: Bearer <token>
class InsurancePoliciesController < ApplicationController
  before_action :authenticate_user!

  # GET /insurance_policies
  #
  # Returns all insurance policies belonging to the authenticated user.
  #
  # @return [void] renders 200 with an array of insurance policy hashes
  def index
    policies = Insurance::InsuranceManager.list(user: current_user)
    render json: policies, status: :ok
  end

  # GET /insurance_policies/:id
  #
  # Returns full detail for a single insurance policy, including associated
  # insured members.
  #
  # @return [void] renders 200 with policy detail hash, or 404 when not found
  def show
    policy = Insurance::InsuranceManager.show(user: current_user, policy_id: params[:id])
    render json: policy, status: :ok
  rescue Insurance::InsuranceManager::NotFoundError
    render_not_found
  end

  # POST /insurance_policies
  #
  # Creates a new insurance policy for the authenticated user. Optionally
  # creates nested insured member records when +insured_members+ is provided.
  #
  # @return [void] renders 201 with the created policy, or 422 on validation failure
  def create
    policy = Insurance::InsuranceManager.create(
      user:   current_user,
      params: insurance_policy_params.to_h.deep_symbolize_keys
    )
    render json: policy, status: :created
  rescue Insurance::InsuranceManager::ValidationError => e
    render_validation_error(e)
  end

  # PATCH /insurance_policies/:id
  #
  # Updates an existing insurance policy belonging to the authenticated user.
  #
  # @return [void] renders 200 with the updated policy, 404 when not found,
  #   or 422 on validation failure
  def update
    policy = Insurance::InsuranceManager.update(
      user:      current_user,
      policy_id: params[:id],
      params:    insurance_policy_params.to_h.deep_symbolize_keys
    )
    render json: policy, status: :ok
  rescue Insurance::InsuranceManager::NotFoundError
    render_not_found
  rescue Insurance::InsuranceManager::ValidationError => e
    render_validation_error(e)
  end

  # DELETE /insurance_policies/:id
  #
  # Permanently deletes an insurance policy and all its associated insured members.
  #
  # @return [void] renders 204 No Content on success, or 404 when not found
  def destroy
    Insurance::InsuranceManager.destroy(user: current_user, policy_id: params[:id])
    head :no_content
  rescue Insurance::InsuranceManager::NotFoundError
    render_not_found
  end

  private

  # Renders a 404 Not Found response for missing or inaccessible insurance policies.
  #
  # @return [void]
  def render_not_found
    render json: { error: "not_found", message: "Insurance policy not found" }, status: :not_found
  end

  # Renders a 422 Unprocessable Entity response for validation failures.
  #
  # @param e [Insurance::InsuranceManager::ValidationError] the raised error
  # @return [void]
  def render_validation_error(e)
    render json: {
      error:   "validation_failed",
      message: e.message,
      details: e.details
    }, status: :unprocessable_entity
  end

  # Strong parameters for insurance policy creation and update.
  #
  # @return [ActionController::Parameters] permitted insurance policy params
  def insurance_policy_params
    params.permit(
      :institution_name,
      :policy_number,
      :policy_type,
      :sum_assured,
      :premium_amount,
      :premium_frequency,
      :renewal_date,
      :policy_start_date,
      :notes,
      insured_members: %i[name member_identifier]
    )
  end
end
