# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Loans endpoints", type: :request do
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
  def valid_loan_attrs(overrides = {})
    {
      institution_name:    "HDFC Bank",
      loan_identifier:     "HL-2024-001",
      outstanding_balance: 250_000_00,
      annual_interest_rate: 8.5,
      interest_rate_type:  "fixed",
      monthly_payment:     25_000_00,
      payment_due_day:     5
    }.merge(overrides)
  end

  # Creates and persists a loan for the given user.
  #
  # @param user [User]
  # @param overrides [Hash]
  # @return [Loan]
  def create_loan(user, overrides = {})
    Loans::LoanManager.create(user: user, params: valid_loan_attrs(overrides))
  end

  # ---------------------------------------------------------------------------
  # GET /loans
  # ---------------------------------------------------------------------------

  describe "GET /loans" do
    context "when authenticated" do
      let!(:user)  { create_user }
      let!(:token) { issue_token_for(user) }

      it "returns 200 with the user's loan list" do
        create_loan(user)

        get "/loans", headers: auth_headers(token), as: :json

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body).to be_an(Array)
        expect(body.length).to eq(1)
        expect(body.first["institution_name"]).to eq("HDFC Bank")
      end

      it "returns an empty array when the user has no loans" do
        get "/loans", headers: auth_headers(token), as: :json

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body).to eq([])
      end

      it "does not include loans belonging to other users" do
        other_user = create_user(identifier: "other@example.com")
        create_loan(other_user)

        get "/loans", headers: auth_headers(token), as: :json

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body).to eq([])
      end
    end

    context "when unauthenticated" do
      it "returns 401" do
        get "/loans", as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # GET /loans/:id
  # ---------------------------------------------------------------------------

  describe "GET /loans/:id" do
    context "when authenticated" do
      let!(:user)  { create_user }
      let!(:token) { issue_token_for(user) }

      it "returns 200 with full loan detail for an existing loan" do
        loan = create_loan(user)

        get "/loans/#{loan.id}", headers: auth_headers(token), as: :json

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["id"]).to eq(loan.id)
        expect(body["institution_name"]).to eq("HDFC Bank")
        expect(body["loan_identifier"]).to eq("HL-2024-001")
        expect(body).to have_key("amortisation_schedule")
        expect(body["amortisation_schedule"]).to be_an(Array)
        expect(body["amortisation_schedule"]).not_to be_empty
      end

      it "returns 404 when the loan does not exist" do
        get "/loans/999999", headers: auth_headers(token), as: :json

        expect(response).to have_http_status(:not_found)
        body = JSON.parse(response.body)
        expect(body["error"]).to eq("not_found")
        expect(body["message"]).to eq("Loan not found")
      end

      it "returns 404 when the loan belongs to another user" do
        other_user = create_user(identifier: "other@example.com")
        loan = create_loan(other_user)

        get "/loans/#{loan.id}", headers: auth_headers(token), as: :json

        expect(response).to have_http_status(:not_found)
        body = JSON.parse(response.body)
        expect(body["error"]).to eq("not_found")
      end
    end

    context "when unauthenticated" do
      it "returns 401" do
        get "/loans/1", as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # POST /loans
  # ---------------------------------------------------------------------------

  describe "POST /loans" do
    context "when authenticated" do
      let!(:user)  { create_user }
      let!(:token) { issue_token_for(user) }

      it "returns 201 with the created loan on valid params" do
        post "/loans",
             params:  valid_loan_attrs,
             headers: auth_headers(token),
             as:      :json

        expect(response).to have_http_status(:created)
        body = JSON.parse(response.body)
        expect(body["id"]).to be_present
        expect(body["institution_name"]).to eq("HDFC Bank")
      end

      it "returns 422 with validation errors on invalid params" do
        post "/loans",
             params:  valid_loan_attrs(outstanding_balance: -1),
             headers: auth_headers(token),
             as:      :json

        expect(response).to have_http_status(:unprocessable_entity)
        body = JSON.parse(response.body)
        expect(body["error"]).to eq("validation_failed")
        expect(body).to have_key("message")
        expect(body).to have_key("details")
      end

      it "returns 422 when fetching a loan whose payment never covers interest (non-converging)" do
        # Create the loan directly so it bypasses schedule computation on create.
        # outstanding_balance=1_000_000_00, rate=24%, monthly_interest≈200_000
        # monthly_payment=100_000 < interest → schedule computation raises NonConvergingLoanError
        loan = create_loan(user,
          outstanding_balance:  1_000_000_00,
          annual_interest_rate: 24.0,
          monthly_payment:      100_000
        )

        get "/loans/#{loan.id}", headers: auth_headers(token), as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        body = JSON.parse(response.body)
        expect(body["error"]).to eq("non_converging_loan")
      end
    end

    context "when unauthenticated" do
      it "returns 401" do
        post "/loans", params: valid_loan_attrs, as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # PATCH /loans/:id
  # ---------------------------------------------------------------------------

  describe "PATCH /loans/:id" do
    context "when authenticated" do
      let!(:user)  { create_user }
      let!(:token) { issue_token_for(user) }

      it "returns 200 with the updated loan on valid params" do
        loan = create_loan(user)

        patch "/loans/#{loan.id}",
              params:  { institution_name: "SBI" },
              headers: auth_headers(token),
              as:      :json

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["institution_name"]).to eq("SBI")
      end

      it "returns 404 when the loan does not exist" do
        patch "/loans/999999",
              params:  { institution_name: "SBI" },
              headers: auth_headers(token),
              as:      :json

        expect(response).to have_http_status(:not_found)
        body = JSON.parse(response.body)
        expect(body["error"]).to eq("not_found")
      end

      it "returns 422 on invalid params" do
        loan = create_loan(user)

        patch "/loans/#{loan.id}",
              params:  { outstanding_balance: 0 },
              headers: auth_headers(token),
              as:      :json

        expect(response).to have_http_status(:unprocessable_entity)
        body = JSON.parse(response.body)
        expect(body["error"]).to eq("validation_failed")
        expect(body).to have_key("details")
      end
    end

    context "when unauthenticated" do
      it "returns 401" do
        patch "/loans/1", params: { institution_name: "SBI" }, as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # DELETE /loans/:id
  # ---------------------------------------------------------------------------

  describe "DELETE /loans/:id" do
    context "when authenticated" do
      let!(:user)  { create_user }
      let!(:token) { issue_token_for(user) }

      it "returns 204 No Content on successful deletion" do
        loan = create_loan(user)

        delete "/loans/#{loan.id}", headers: auth_headers(token), as: :json

        expect(response).to have_http_status(:no_content)
        expect(response.body).to be_empty
      end

      it "removes the loan from the database" do
        loan = create_loan(user)

        expect {
          delete "/loans/#{loan.id}", headers: auth_headers(token), as: :json
        }.to change(Loan, :count).by(-1)
      end

      it "returns 404 when the loan does not exist" do
        delete "/loans/999999", headers: auth_headers(token), as: :json

        expect(response).to have_http_status(:not_found)
        body = JSON.parse(response.body)
        expect(body["error"]).to eq("not_found")
      end

      it "returns 404 when the loan belongs to another user" do
        other_user = create_user(identifier: "other@example.com")
        loan = create_loan(other_user)

        delete "/loans/#{loan.id}", headers: auth_headers(token), as: :json

        expect(response).to have_http_status(:not_found)
      end
    end

    context "when unauthenticated" do
      it "returns 401" do
        delete "/loans/1", as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
