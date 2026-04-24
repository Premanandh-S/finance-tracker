# frozen_string_literal: true

module InsurancePolicies
  # Handles create, update, and destroy operations for {InsuredMember} records
  # nested under an {InsurancePolicy}.
  #
  # All actions require a valid JWT Bearer token. Business logic is delegated to
  # {Insurance::InsuranceManager}. The response for create and update is the full
  # updated policy detail hash (including all insured members).
  #
  # @example Authenticated create request
  #   POST /insurance_policies/1/insured_members
  #   Authorization: Bearer <token>
  #   { "name": "Jane Doe", "member_identifier": "MEM-001" }
  class InsuredMembersController < ApplicationController
    before_action :authenticate_user!

    # POST /insurance_policies/:insurance_policy_id/insured_members
    #
    # Adds a new insured member to an insurance policy. Returns the full updated
    # policy detail including all insured members.
    #
    # @return [void] renders 201 with updated policy detail, 422 on validation failure,
    #   or 404 when the policy is not found
    def create
      result = Insurance::InsuranceManager.add_or_update_member(
        user:      current_user,
        policy_id: params[:insurance_policy_id],
        params:    member_params.to_h.deep_symbolize_keys
      )
      render json: result, status: :created
    rescue Insurance::InsuranceManager::NotFoundError
      render_not_found
    rescue Insurance::InsuranceManager::ValidationError => e
      render_validation_error(e)
    end

    # PATCH /insurance_policies/:insurance_policy_id/insured_members/:id
    #
    # Updates an existing insured member on an insurance policy. Returns the full
    # updated policy detail including all insured members.
    #
    # @return [void] renders 200 with updated policy detail, 422 on validation failure,
    #   or 404 when the policy or member is not found
    def update
      result = Insurance::InsuranceManager.add_or_update_member(
        user:      current_user,
        policy_id: params[:insurance_policy_id],
        params:    member_params.to_h.deep_symbolize_keys.merge(id: params[:id].to_i)
      )
      render json: result, status: :ok
    rescue Insurance::InsuranceManager::NotFoundError
      render_not_found
    rescue Insurance::InsuranceManager::ValidationError => e
      render_validation_error(e)
    end

    # DELETE /insurance_policies/:insurance_policy_id/insured_members/:id
    #
    # Removes an insured member from an insurance policy. Returns the full updated
    # policy detail.
    #
    # @return [void] renders 200 with updated policy detail, or 404 when not found
    def destroy
      result = Insurance::InsuranceManager.remove_member(
        user:      current_user,
        policy_id: params[:insurance_policy_id],
        member_id: params[:id]
      )
      render json: result, status: :ok
    rescue Insurance::InsuranceManager::NotFoundError
      render_not_found
    end

    private

    # Renders a 404 Not Found response for missing or inaccessible policies or members.
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

    # Strong parameters for insured member creation and update.
    #
    # @return [ActionController::Parameters] permitted member params
    def member_params
      params.permit(:name, :member_identifier)
    end
  end
end
