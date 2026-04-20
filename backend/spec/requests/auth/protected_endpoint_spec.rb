# frozen_string_literal: true

require "rails_helper"

# 5.9 — Protected endpoint token validation
#
# Uses DELETE /auth/logout as the protected endpoint because it requires
# authenticate_user! before the action runs.
RSpec.describe "Protected endpoint token validation", type: :request do
  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  def create_user(identifier: "protected@example.com")
    User.create!(identifier: identifier, verified: true)
  end

  def issue_token_for(user)
    Auth::SessionService.issue_jwt(user)
  end

  def hit_protected_endpoint(token: nil)
    headers = {}
    headers["Authorization"] = "Bearer #{token}" if token
    delete "/auth/logout", headers: headers, as: :json
  end

  # ---------------------------------------------------------------------------
  # 5.9 — Token validation scenarios
  # ---------------------------------------------------------------------------

  describe "expired token" do
    let!(:user) { create_user }

    it "returns 401 with token_expired" do
      token = nil
      travel_to(25.hours.ago) { token = issue_token_for(user) }

      hit_protected_endpoint(token: token)

      expect(response).to have_http_status(:unauthorized)
      body = JSON.parse(response.body)
      expect(body["error"]).to eq("token_expired")
    end
  end

  describe "malformed token" do
    it "returns 401 with token_invalid for a garbage string" do
      hit_protected_endpoint(token: "not.a.real.jwt")

      expect(response).to have_http_status(:unauthorized)
      body = JSON.parse(response.body)
      expect(body["error"]).to eq("token_invalid")
    end

    it "returns 401 with token_invalid for a tampered token" do
      user  = create_user
      token = issue_token_for(user)

      # Flip the last character to tamper with the signature
      tampered = token[0..-2] + (token[-1] == "a" ? "b" : "a")

      hit_protected_endpoint(token: tampered)

      expect(response).to have_http_status(:unauthorized)
      body = JSON.parse(response.body)
      expect(body["error"]).to eq("token_invalid")
    end
  end

  describe "denylisted token" do
    let!(:user) { create_user }

    it "returns 401 with token_invalid after the token has been logged out" do
      token = issue_token_for(user)

      # Denylist the token via logout
      delete "/auth/logout",
             headers: { "Authorization" => "Bearer #{token}" },
             as: :json
      expect(response).to have_http_status(:ok)

      # Now the same token should be rejected
      hit_protected_endpoint(token: token)

      expect(response).to have_http_status(:unauthorized)
      body = JSON.parse(response.body)
      expect(body["error"]).to eq("token_invalid")
    end
  end

  describe "missing Authorization header" do
    it "returns 401 when no token is provided" do
      hit_protected_endpoint

      expect(response).to have_http_status(:unauthorized)
      body = JSON.parse(response.body)
      expect(body["error"]).to eq("token_invalid")
    end
  end
end
