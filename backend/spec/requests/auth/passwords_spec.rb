# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Password endpoints", type: :request do
  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  def create_user(identifier: "user@example.com", password: "initialpassword")
    user = User.new(identifier: identifier, verified: true)
    user.password = password if password
    user.save!
    user
  end

  def stub_otp_delivery!
    delivery_double = instance_double(Auth::OtpDeliveryService, deliver: nil)
    allow(Auth::OtpDeliveryService).to receive(:new).and_return(delivery_double)
  end

  def reset_request(identifier:)
    post "/auth/password/reset/request",
         params: { identifier: identifier },
         as: :json
  end

  def reset_confirm(identifier:, otp:, new_password:)
    post "/auth/password/reset/confirm",
         params: { identifier: identifier, otp: otp, new_password: new_password },
         as: :json
  end

  # Creates an OTP code record directly, bypassing delivery.
  # Returns the plaintext code.
  def create_otp_for(user, expires_in: 10.minutes)
    plaintext = "789012"
    digest    = BCrypt::Password.create(plaintext)
    user.otp_codes.create!(
      code_digest: digest,
      expires_at:  Time.current + expires_in
    )
    plaintext
  end

  def issue_token_for(user)
    Auth::SessionService.issue_jwt(user)
  end

  # ---------------------------------------------------------------------------
  # 5.7 — POST /auth/password/reset/request
  # ---------------------------------------------------------------------------

  describe "POST /auth/password/reset/request" do
    before { stub_otp_delivery! }

    context "with a registered identifier" do
      let!(:user) { create_user }

      it "returns 200 with a generic success message" do
        reset_request(identifier: user.identifier)

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body).to have_key("message")
      end
    end

    context "with an unregistered identifier" do
      it "returns 200 with the same generic success message (no enumeration)" do
        reset_request(identifier: "nobody@example.com")

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body).to have_key("message")
      end

      it "returns the same response body as for a registered identifier" do
        create_user(identifier: "registered@example.com")

        reset_request(identifier: "registered@example.com")
        registered_body = JSON.parse(response.body)

        reset_request(identifier: "nobody@example.com")
        unregistered_body = JSON.parse(response.body)

        expect(unregistered_body["message"]).to eq(registered_body["message"])
      end
    end
  end

  # ---------------------------------------------------------------------------
  # 5.8 — POST /auth/password/reset/confirm
  # ---------------------------------------------------------------------------

  describe "POST /auth/password/reset/confirm" do
    context "with a valid OTP and new password" do
      let!(:user) { create_user }

      it "returns 200 with Password reset successful message" do
        otp = create_otp_for(user)

        reset_confirm(identifier: user.identifier, otp: otp, new_password: "newpassword123")

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["message"]).to eq("Password reset successful.")
      end

      it "allows the new password to authenticate" do
        otp = create_otp_for(user)
        reset_confirm(identifier: user.identifier, otp: otp, new_password: "newpassword123")

        post "/auth/login",
             params: { identifier: user.identifier, method: "password", password: "newpassword123" },
             as: :json

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to have_key("token")
      end

      it "rejects all JWTs issued before the reset" do
        prior_token = issue_token_for(user)
        otp = create_otp_for(user)

        # Small sleep to ensure jwt_issued_before > prior token iat
        travel_to(1.second.from_now) do
          reset_confirm(identifier: user.identifier, otp: otp, new_password: "newpassword123")
        end

        delete "/auth/logout",
               headers: { "Authorization" => "Bearer #{prior_token}" },
               as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "with an invalid (wrong) OTP" do
      let!(:user) { create_user }

      it "returns 401 with otp_invalid" do
        create_otp_for(user)

        reset_confirm(identifier: user.identifier, otp: "000000", new_password: "newpassword123")

        expect(response).to have_http_status(:unauthorized)
        body = JSON.parse(response.body)
        expect(body["error"]).to eq("otp_invalid")
      end

      it "does not change the password" do
        original_digest = user.reload.password_digest
        create_otp_for(user)

        reset_confirm(identifier: user.identifier, otp: "000000", new_password: "newpassword123")

        expect(user.reload.password_digest).to eq(original_digest)
      end
    end

    context "with a new password that is too short" do
      let!(:user) { create_user }

      it "returns 422 with password_too_short" do
        otp = create_otp_for(user)

        reset_confirm(identifier: user.identifier, otp: otp, new_password: "short")

        expect(response).to have_http_status(:unprocessable_entity)
        body = JSON.parse(response.body)
        expect(body["error"]).to eq("password_too_short")
      end
    end
  end
end
