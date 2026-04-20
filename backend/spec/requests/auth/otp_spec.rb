# frozen_string_literal: true

require "rails_helper"

RSpec.describe "OTP endpoints", type: :request do
  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  def create_user(identifier: "user@example.com")
    User.create!(identifier: identifier, verified: false)
  end

  def stub_otp_delivery!
    delivery_double = instance_double(Auth::OtpDeliveryService, deliver: nil)
    allow(Auth::OtpDeliveryService).to receive(:new).and_return(delivery_double)
  end

  def request_otp(identifier:)
    post "/auth/otp/request", params: { identifier: identifier }, as: :json
  end

  def verify_otp(identifier:, otp:)
    post "/auth/otp/verify", params: { identifier: identifier, otp: otp }, as: :json
  end

  # Creates an OTP code record directly, bypassing delivery.
  # Returns the plaintext code.
  def create_otp_for(user, expires_in: 10.minutes)
    plaintext = "123456"
    digest    = BCrypt::Password.create(plaintext)
    user.otp_codes.create!(
      code_digest: digest,
      expires_at:  Time.current + expires_in
    )
    plaintext
  end

  # ---------------------------------------------------------------------------
  # 5.2 — POST /auth/otp/request
  # ---------------------------------------------------------------------------

  describe "POST /auth/otp/request" do
    context "with a registered identifier" do
      let!(:user) { create_user }

      before { stub_otp_delivery! }

      it "returns 200 with OTP sent message" do
        request_otp(identifier: user.identifier)

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["message"]).to eq("OTP sent")
      end
    end

    context "with an unknown identifier" do
      it "returns 401 with invalid_credentials" do
        request_otp(identifier: "nobody@example.com")

        expect(response).to have_http_status(:unauthorized)
        body = JSON.parse(response.body)
        expect(body["error"]).to eq("invalid_credentials")
      end
    end

    context "when rate limit is exceeded" do
      let!(:user) { create_user }

      before do
        stub_otp_delivery!
        # Seed 5 request logs within the 60-minute window
        Auth::OtpService::RATE_LIMIT_MAX.times do
          user.otp_request_logs.create!(requested_at: Time.current)
        end
      end

      it "returns 429" do
        request_otp(identifier: user.identifier)

        expect(response).to have_http_status(429)
      end

      it "returns otp_rate_limit error code" do
        request_otp(identifier: user.identifier)

        body = JSON.parse(response.body)
        expect(body["error"]).to eq("otp_rate_limit")
      end

      it "includes retry_after in the response" do
        request_otp(identifier: user.identifier)

        body = JSON.parse(response.body)
        expect(body).to have_key("retry_after")
      end
    end
  end

  # ---------------------------------------------------------------------------
  # 5.3 — POST /auth/otp/verify
  # ---------------------------------------------------------------------------

  describe "POST /auth/otp/verify" do
    context "with a valid OTP" do
      let!(:user) { create_user }

      it "returns 200 with a JWT token" do
        plaintext = create_otp_for(user)

        verify_otp(identifier: user.identifier, otp: plaintext)

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body).to have_key("token")
        expect(body["token"]).to be_a(String)
        expect(body["token"]).not_to be_empty
      end
    end

    context "with an invalid (wrong) OTP" do
      let!(:user) { create_user }

      it "returns 401 with otp_invalid" do
        create_otp_for(user)

        verify_otp(identifier: user.identifier, otp: "000000")

        expect(response).to have_http_status(:unauthorized)
        body = JSON.parse(response.body)
        expect(body["error"]).to eq("otp_invalid")
      end
    end

    context "with an expired OTP" do
      let!(:user) { create_user }

      it "returns 401 with otp_invalid" do
        plaintext = create_otp_for(user, expires_in: -1.second)

        verify_otp(identifier: user.identifier, otp: plaintext)

        expect(response).to have_http_status(:unauthorized)
        body = JSON.parse(response.body)
        expect(body["error"]).to eq("otp_invalid")
      end
    end

    context "after 5 consecutive failed attempts" do
      let!(:user) { create_user }

      it "returns 423 with otp_locked" do
        plaintext = create_otp_for(user)

        # Exhaust all allowed attempts
        Auth::OtpService::OTP_MAX_ATTEMPTS.times do
          verify_otp(identifier: user.identifier, otp: "000000")
        end

        # Next attempt — even with the correct code — should be locked
        verify_otp(identifier: user.identifier, otp: plaintext)

        expect(response).to have_http_status(423)
        body = JSON.parse(response.body)
        expect(body["error"]).to eq("otp_locked")
      end
    end
  end
end
