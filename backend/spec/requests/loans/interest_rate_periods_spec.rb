# frozen_string_literal: true

require "rails_helper"

RSpec.describe "InterestRatePeriods endpoints", type: :request do
  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  # Creates a verified user with the given identifier.
  #
  # @param identifier [String]
  # @return [User]
  def create_user(identifier: "user@example.com")
    User.create!(identifier: identifier, verified: true)
  end

  # Issues a JWT for the given user.
  #
  # @param user [User]
  # @return [String] signed JWT
  def issue_token_for(user)
    Auth::SessionService.issue_jwt(user)
  end

  # Returns Authorization header hash for the given token.
  #
  # @param token [String]
  # @return [Hash]
  def auth_headers(token)
    { "Authorization" => "Bearer #{token}" }
  end

  # Builds a valid set of loan attributes for a fixed-rate loan.
  #
  # @param overrides [Hash]
  # @return [Hash]
  def valid_fixed_loan_attrs(overrides = {})
    {
      institution_name:     "HDFC Bank",
      loan_identifier:      "HL-2024-001",
      outstanding_balance:  250_000_00,
      annual_interest_rate: 8.5,
      interest_rate_type:   "fixed",
      monthly_payment:      25_000_00,
      payment_due_day:      5
    }.merge(overrides)
  end

  # Builds a valid set of loan attributes for a floating-rate loan.
  #
  # @param overrides [Hash]
  # @return [Hash]
  def valid_floating_loan_attrs(overrides = {})
    {
      institution_name:      "SBI",
      loan_identifier:       "HL-2024-002",
      outstanding_balance:   100_000_00,
      annual_interest_rate:  9.0,
      interest_rate_type:    "floating",
      monthly_payment:       10_000_00,
      payment_due_day:       10,
      interest_rate_periods: [
        { start_date: "2024-01-01", annual_interest_rate: 9.0 }
      ]
    }.merge(overrides)
  end

  # Creates and persists a fixed-rate loan for the given user.
  #
  # @param user [User]
  # @param overrides [Hash]
  # @return [Loan]
  def create_fixed_loan(user, overrides = {})
    Loans::LoanManager.create(user: user, params: valid_fixed_loan_attrs(overrides))
  end

  # Creates and persists a floating-rate loan for the given user.
  #
  # @param user [User]
  # @param overrides [Hash]
  # @return [Loan]
  def create_floating_loan(user, overrides = {})
    Loans::LoanManager.create(user: user, params: valid_floating_loan_attrs(overrides))
  end

  # ---------------------------------------------------------------------------
  # POST /loans/:loan_id/interest_rate_periods
  # ---------------------------------------------------------------------------

  describe "POST /loans/:loan_id/interest_rate_periods" do
    context "when authenticated" do
      let!(:user)  { create_user }
      let!(:token) { issue_token_for(user) }

      it "returns 201 with updated loan detail for a floating-rate loan" do
        loan = create_floating_loan(user)

        post "/loans/#{loan.id}/interest_rate_periods",
             params:  { start_date: "2025-01-01", annual_interest_rate: 10.5 },
             headers: auth_headers(token),
             as:      :json

        expect(response).to have_http_status(:created)
        body = JSON.parse(response.body)
        expect(body["id"]).to eq(loan.id)
        expect(body).to have_key("amortisation_schedule")
        expect(body["amortisation_schedule"]).to be_an(Array)
        expect(body["amortisation_schedule"]).not_to be_empty
        expect(body["interest_rate_periods"].length).to be >= 2
      end

      it "returns 422 with invalid_operation for a fixed-rate loan" do
        loan = create_fixed_loan(user)

        post "/loans/#{loan.id}/interest_rate_periods",
             params:  { start_date: "2025-01-01", annual_interest_rate: 9.0 },
             headers: auth_headers(token),
             as:      :json

        expect(response).to have_http_status(:unprocessable_entity)
        body = JSON.parse(response.body)
        expect(body["error"]).to eq("invalid_operation")
        expect(body).to have_key("message")
        expect(body).to have_key("details")
      end

      it "returns 404 when the loan does not exist" do
        post "/loans/999999/interest_rate_periods",
             params:  { start_date: "2025-01-01", annual_interest_rate: 9.0 },
             headers: auth_headers(token),
             as:      :json

        expect(response).to have_http_status(:not_found)
        body = JSON.parse(response.body)
        expect(body["error"]).to eq("not_found")
        expect(body["message"]).to eq("Loan not found")
      end

      it "returns 404 when the loan belongs to another user" do
        other_user = create_user(identifier: "other@example.com")
        loan = create_floating_loan(other_user)

        post "/loans/#{loan.id}/interest_rate_periods",
             params:  { start_date: "2025-01-01", annual_interest_rate: 9.0 },
             headers: auth_headers(token),
             as:      :json

        expect(response).to have_http_status(:not_found)
        body = JSON.parse(response.body)
        expect(body["error"]).to eq("not_found")
      end
    end

    context "when unauthenticated" do
      it "returns 401" do
        post "/loans/1/interest_rate_periods",
             params: { start_date: "2025-01-01", annual_interest_rate: 9.0 },
             as:     :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # PATCH /loans/:loan_id/interest_rate_periods/:id
  # ---------------------------------------------------------------------------

  describe "PATCH /loans/:loan_id/interest_rate_periods/:id" do
    context "when authenticated" do
      let!(:user)  { create_user }
      let!(:token) { issue_token_for(user) }

      it "returns 200 with updated loan detail after updating a rate period" do
        loan   = create_floating_loan(user)
        period = loan.interest_rate_periods.first

        patch "/loans/#{loan.id}/interest_rate_periods/#{period.id}",
              params:  { annual_interest_rate: 11.0 },
              headers: auth_headers(token),
              as:      :json

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["id"]).to eq(loan.id)
        expect(body).to have_key("amortisation_schedule")
        expect(body["amortisation_schedule"]).not_to be_empty

        updated_period = body["interest_rate_periods"].find { |p| p["id"] == period.id }
        expect(updated_period["annual_interest_rate"].to_f).to eq(11.0)
      end

      it "returns 404 when the loan does not exist" do
        patch "/loans/999999/interest_rate_periods/1",
              params:  { annual_interest_rate: 11.0 },
              headers: auth_headers(token),
              as:      :json

        expect(response).to have_http_status(:not_found)
        body = JSON.parse(response.body)
        expect(body["error"]).to eq("not_found")
      end

      it "returns 404 when the loan belongs to another user" do
        other_user = create_user(identifier: "other@example.com")
        loan       = create_floating_loan(other_user)
        period     = loan.interest_rate_periods.first

        patch "/loans/#{loan.id}/interest_rate_periods/#{period.id}",
              params:  { annual_interest_rate: 11.0 },
              headers: auth_headers(token),
              as:      :json

        expect(response).to have_http_status(:not_found)
        body = JSON.parse(response.body)
        expect(body["error"]).to eq("not_found")
      end
    end

    context "when unauthenticated" do
      it "returns 401" do
        patch "/loans/1/interest_rate_periods/1",
              params: { annual_interest_rate: 11.0 },
              as:     :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # DELETE /loans/:loan_id/interest_rate_periods/:id
  # ---------------------------------------------------------------------------

  describe "DELETE /loans/:loan_id/interest_rate_periods/:id" do
    context "when authenticated" do
      let!(:user)  { create_user }
      let!(:token) { issue_token_for(user) }

      it "returns 204 No Content on successful deletion" do
        loan   = create_floating_loan(user)
        # Add a second period so we can delete one without violating model constraints
        period = loan.interest_rate_periods.create!(
          start_date:           "2025-06-01",
          annual_interest_rate: 10.0
        )

        delete "/loans/#{loan.id}/interest_rate_periods/#{period.id}",
               headers: auth_headers(token),
               as:      :json

        expect(response).to have_http_status(:no_content)
        expect(response.body).to be_empty
      end

      it "removes the rate period from the database" do
        loan   = create_floating_loan(user)
        period = loan.interest_rate_periods.create!(
          start_date:           "2025-06-01",
          annual_interest_rate: 10.0
        )

        expect {
          delete "/loans/#{loan.id}/interest_rate_periods/#{period.id}",
                 headers: auth_headers(token),
                 as:      :json
        }.to change(InterestRatePeriod, :count).by(-1)
      end

      it "returns 404 when the loan does not exist" do
        delete "/loans/999999/interest_rate_periods/1",
               headers: auth_headers(token),
               as:      :json

        expect(response).to have_http_status(:not_found)
        body = JSON.parse(response.body)
        expect(body["error"]).to eq("not_found")
        expect(body["message"]).to eq("Loan not found")
      end

      it "returns 404 when the loan belongs to another user" do
        other_user = create_user(identifier: "other@example.com")
        loan       = create_floating_loan(other_user)
        period     = loan.interest_rate_periods.first

        delete "/loans/#{loan.id}/interest_rate_periods/#{period.id}",
               headers: auth_headers(token),
               as:      :json

        expect(response).to have_http_status(:not_found)
        body = JSON.parse(response.body)
        expect(body["error"]).to eq("not_found")
      end

      it "returns 404 when the rate period does not exist" do
        loan = create_floating_loan(user)

        delete "/loans/#{loan.id}/interest_rate_periods/999999",
               headers: auth_headers(token),
               as:      :json

        expect(response).to have_http_status(:not_found)
        body = JSON.parse(response.body)
        expect(body["error"]).to eq("not_found")
      end
    end

    context "when unauthenticated" do
      it "returns 401" do
        delete "/loans/1/interest_rate_periods/1", as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
