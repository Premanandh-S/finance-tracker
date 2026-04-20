# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Session endpoints", type: :request do
  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  def create_user(identifier: "user@example.com", password: nil)
    user = User.new(identifier: identifier, verified: true)
    user.password = password if password
    user.save!
    user
  end

  def stub_otp_delivery!
    delivery_double = instance_double(Auth::OtpDeliveryService, deliver: nil)
    allow(Auth::OtpDeliveryService).to receive(:new).and_return(delivery_double)
  end

  def login(identifier:, method:, password: nil)
    body = { identifier: identifier, method: method }
    body[:password] = password if password
    post "/auth/login", params: body, as: :json
  end

  def logout(token:)
    delete "/auth/logout",
           headers: { "Authorization" => "Bearer #{token}" },
           as: :json
  end

  def refresh(token:)
    post "/auth/refresh",
         headers: { "Authorization" => "Bearer #{token}" },
         as: :json
  end

  def issue_token_for(user)
    Auth::SessionService.issue_jwt(user)
  end

  # Creates an OTP code record directly, bypassing delivery.
  # Returns the plaintext code.
  def create_otp_for(user, expires_in: 10.minutes)
    plaintext = "654321"
    digest    = BCrypt::Password.create(plaintext)
    user.otp_codes.create!(
      code_digest: digest,
      expires_at:  Time.current + expires_in
    )
    plaintext
  end

  # ---------------------------------------------------------------------------
  # 5.4 — POST /auth/login
  # ---------------------------------------------------------------------------

  describe "POST /auth/login" do
    context "OTP authentication method" do
      let!(:user) { create_user }

      before { stub_otp_delivery! }

      it "returns 200 with OTP sent message" do
        login(identifier: user.identifier, method: "otp")

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["message"]).to eq("OTP sent")
      end
    end

    context "password authentication method with correct password" do
      let!(:user) { create_user(password: "correctpassword") }

      it "returns 200 with a JWT token" do
        login(identifier: user.identifier, method: "password", password: "correctpassword")

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body).to have_key("token")
        expect(body["token"]).to be_a(String)
        expect(body["token"]).not_to be_empty
      end
    end

    context "with an unknown identifier (no enumeration)" do
      it "returns 401 with invalid_credentials" do
        login(identifier: "nobody@example.com", method: "password", password: "anything")

        expect(response).to have_http_status(:unauthorized)
        body = JSON.parse(response.body)
        expect(body["error"]).to eq("invalid_credentials")
      end

      it "returns the same response as a wrong password on a real account" do
        create_user(password: "realpassword")

        login(identifier: "nobody@example.com", method: "password", password: "anything")
        unknown_body = JSON.parse(response.body)

        login(identifier: "user@example.com", method: "password", password: "wrongpassword")
        wrong_body = JSON.parse(response.body)

        expect(unknown_body["error"]).to eq(wrong_body["error"])
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "with a wrong password" do
      let!(:user) { create_user(password: "correctpassword") }

      it "returns 401 with invalid_credentials" do
        login(identifier: user.identifier, method: "password", password: "wrongpassword")

        expect(response).to have_http_status(:unauthorized)
        body = JSON.parse(response.body)
        expect(body["error"]).to eq("invalid_credentials")
      end
    end

    context "when account is locked" do
      let!(:user) { create_user(password: "correctpassword") }

      before do
        user.update_columns(
          password_failed_attempts: Auth::PasswordAuthService::MAX_FAILED_ATTEMPTS,
          password_locked_until:    15.minutes.from_now
        )
      end

      it "returns 423 with account_locked" do
        login(identifier: user.identifier, method: "password", password: "correctpassword")

        expect(response).to have_http_status(423)
        body = JSON.parse(response.body)
        expect(body["error"]).to eq("account_locked")
      end
    end
  end

  # ---------------------------------------------------------------------------
  # 5.5 — DELETE /auth/logout
  # ---------------------------------------------------------------------------

  describe "DELETE /auth/logout" do
    let!(:user) { create_user }

    context "with a valid token" do
      it "returns 200 with Logged out message" do
        token = issue_token_for(user)
        logout(token: token)

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["message"]).to eq("Logged out")
      end

      it "adds the token to the denylist" do
        token = issue_token_for(user)
        expect { logout(token: token) }.to change(JwtDenylist, :count).by(1)
      end

      it "causes a subsequent request with the same token to return 401" do
        token = issue_token_for(user)
        logout(token: token)

        # Use the same token on a protected endpoint
        delete "/auth/logout",
               headers: { "Authorization" => "Bearer #{token}" },
               as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "with no token" do
      it "returns 401" do
        delete "/auth/logout", as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # 5.6 — POST /auth/refresh
  # ---------------------------------------------------------------------------

  describe "POST /auth/refresh" do
    let!(:user) { create_user }

    context "with a valid token" do
      it "returns 200 with a new token" do
        token = issue_token_for(user)
        refresh(token: token)

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body).to have_key("token")
        expect(body["token"]).to be_a(String)
        expect(body["token"]).not_to be_empty
      end

      it "issues a token different from the original" do
        token = issue_token_for(user)
        refresh(token: token)

        new_token = JSON.parse(response.body)["token"]
        expect(new_token).not_to eq(token)
      end

      it "rejects the old token after refresh" do
        token = issue_token_for(user)
        refresh(token: token)

        # Old token should now be denylisted
        delete "/auth/logout",
               headers: { "Authorization" => "Bearer #{token}" },
               as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "with an expired token" do
      it "returns 401 with token_expired" do
        token = nil
        travel_to(25.hours.ago) { token = issue_token_for(user) }

        refresh(token: token)

        expect(response).to have_http_status(:unauthorized)
        body = JSON.parse(response.body)
        expect(body["error"]).to eq("token_expired")
      end
    end

    context "with a malformed token" do
      it "returns 401 with token_invalid" do
        refresh(token: "this.is.not.a.valid.jwt")

        expect(response).to have_http_status(:unauthorized)
        body = JSON.parse(response.body)
        expect(body["error"]).to eq("token_invalid")
      end
    end
  end
end
