# frozen_string_literal: true

require "rails_helper"

RSpec.describe Auth::PasswordResetService do
  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  def create_user(overrides = {})
    User.create!({
      identifier: "user@example.com",
      password:   "oldpassword",
      verified:   true
    }.merge(overrides))
  end

  def create_otp_code(user, overrides = {})
    OtpCode.create!({
      user:            user,
      code_digest:     BCrypt::Password.create("123456"),
      expires_at:      10.minutes.from_now,
      used:            false,
      failed_attempts: 0
    }.merge(overrides))
  end

  # ---------------------------------------------------------------------------
  # .request_reset
  # ---------------------------------------------------------------------------
  describe ".request_reset" do
    context "when the identifier belongs to a registered user" do
      let(:user) { create_user }
      let(:otp_service_double) { instance_double(Auth::OtpService, request_otp: "042891") }

      before do
        allow(Auth::OtpService).to receive(:new).with(user).and_return(otp_service_double)
      end

      it "returns :ok" do
        expect(described_class.request_reset(user.identifier)).to eq(:ok)
      end

      it "delegates to Auth::OtpService#request_otp" do
        described_class.request_reset(user.identifier)
        expect(otp_service_double).to have_received(:request_otp)
      end
    end

    context "when the identifier does not exist" do
      it "returns :ok without raising (no enumeration)" do
        expect(described_class.request_reset("nobody@example.com")).to eq(:ok)
      end

      it "does not attempt to create an OTP" do
        expect(Auth::OtpService).not_to receive(:new)
        described_class.request_reset("nobody@example.com")
      end
    end

    context "when OtpService raises RateLimitError" do
      let(:user) { create_user }
      let(:otp_service_double) do
        instance_double(Auth::OtpService).tap do |d|
          allow(d).to receive(:request_otp)
            .and_raise(Auth::OtpService::RateLimitError, "limit exceeded")
        end
      end

      before do
        allow(Auth::OtpService).to receive(:new).with(user).and_return(otp_service_double)
      end

      it "propagates the RateLimitError" do
        expect {
          described_class.request_reset(user.identifier)
        }.to raise_error(Auth::OtpService::RateLimitError)
      end
    end

    context "when OtpService raises DeliveryError" do
      let(:user) { create_user }
      let(:otp_service_double) do
        instance_double(Auth::OtpService).tap do |d|
          allow(d).to receive(:request_otp)
            .and_raise(Auth::OtpService::DeliveryError, "SMS failed")
        end
      end

      before do
        allow(Auth::OtpService).to receive(:new).with(user).and_return(otp_service_double)
      end

      it "propagates the DeliveryError" do
        expect {
          described_class.request_reset(user.identifier)
        }.to raise_error(Auth::OtpService::DeliveryError)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # .confirm_reset
  # ---------------------------------------------------------------------------
  describe ".confirm_reset" do
    # -------------------------------------------------------------------------
    # Success path
    # -------------------------------------------------------------------------
    context "with a valid OTP and a valid new password" do
      let(:user)       { create_user }
      let!(:otp_code)  { create_otp_code(user) }

      it "returns the user" do
        result = described_class.confirm_reset(user.identifier, "123456", "newpassword1")
        expect(result).to eq(user)
      end

      it "updates the password digest so the new password authenticates" do
        described_class.confirm_reset(user.identifier, "123456", "newpassword1")
        expect(user.reload.authenticate("newpassword1")).to be_truthy
      end

      it "the old password no longer authenticates" do
        described_class.confirm_reset(user.identifier, "123456", "newpassword1")
        expect(user.reload.authenticate("oldpassword")).to be_falsey
      end

      it "marks the OTP as used" do
        described_class.confirm_reset(user.identifier, "123456", "newpassword1")
        expect(otp_code.reload.used).to be(true)
      end

      it "resets password_failed_attempts to 0" do
        user.update_columns(password_failed_attempts: 5)
        described_class.confirm_reset(user.identifier, "123456", "newpassword1")
        expect(user.reload.password_failed_attempts).to eq(0)
      end

      it "clears password_locked_until" do
        user.update_columns(password_locked_until: 10.minutes.from_now)
        described_class.confirm_reset(user.identifier, "123456", "newpassword1")
        expect(user.reload.password_locked_until).to be_nil
      end

      it "invalidates all existing JWTs by setting jwt_issued_before" do
        freeze_time do
          token = Auth::SessionService.issue_jwt(user)
          described_class.confirm_reset(user.identifier, "123456", "newpassword1")

          expect {
            Auth::SessionService.verify_jwt(token)
          }.to raise_error(Auth::SessionService::DenylistedTokenError)
        end
      end

      it "sets jwt_issued_before to approximately now" do
        freeze_time do
          described_class.confirm_reset(user.identifier, "123456", "newpassword1")
          expect(user.reload.jwt_issued_before).to be_within(1.second).of(Time.now)
        end
      end
    end

    # -------------------------------------------------------------------------
    # Unknown identifier
    # -------------------------------------------------------------------------
    context "when the identifier does not exist" do
      it "raises InvalidOtpError (generic — no enumeration)" do
        expect {
          described_class.confirm_reset("nobody@example.com", "123456", "newpassword1")
        }.to raise_error(Auth::PasswordResetService::InvalidOtpError)
      end
    end

    # -------------------------------------------------------------------------
    # No active OTP
    # -------------------------------------------------------------------------
    context "when there is no active OTP for the user" do
      let(:user) { create_user }

      it "raises InvalidOtpError when no OTP record exists" do
        expect {
          described_class.confirm_reset(user.identifier, "123456", "newpassword1")
        }.to raise_error(Auth::PasswordResetService::InvalidOtpError)
      end

      it "raises InvalidOtpError when the OTP is expired" do
        create_otp_code(user, expires_at: 1.minute.ago)
        expect {
          described_class.confirm_reset(user.identifier, "123456", "newpassword1")
        }.to raise_error(Auth::PasswordResetService::InvalidOtpError)
      end

      it "raises InvalidOtpError when the OTP has already been used" do
        create_otp_code(user, used: true)
        expect {
          described_class.confirm_reset(user.identifier, "123456", "newpassword1")
        }.to raise_error(Auth::PasswordResetService::InvalidOtpError)
      end
    end

    # -------------------------------------------------------------------------
    # Wrong OTP
    # -------------------------------------------------------------------------
    context "when the submitted OTP does not match" do
      let(:user)      { create_user }
      let!(:otp_code) { create_otp_code(user) }

      it "raises InvalidOtpError" do
        expect {
          described_class.confirm_reset(user.identifier, "000000", "newpassword1")
        }.to raise_error(Auth::PasswordResetService::InvalidOtpError)
      end

      it "does not update the password" do
        original_digest = user.password_digest
        described_class.confirm_reset(user.identifier, "000000", "newpassword1") rescue nil
        expect(user.reload.password_digest).to eq(original_digest)
      end

      it "increments the OTP failed_attempts counter" do
        described_class.confirm_reset(user.identifier, "000000", "newpassword1") rescue nil
        expect(otp_code.reload.failed_attempts).to eq(1)
      end

      it "does not invalidate JWTs" do
        token = Auth::SessionService.issue_jwt(user)
        described_class.confirm_reset(user.identifier, "000000", "newpassword1") rescue nil
        expect { Auth::SessionService.verify_jwt(token) }.not_to raise_error
      end
    end

    # -------------------------------------------------------------------------
    # OTP locked after 5 failed attempts
    # -------------------------------------------------------------------------
    context "when the OTP has reached the maximum failed attempts" do
      let(:user)      { create_user }
      let!(:otp_code) { create_otp_code(user, failed_attempts: 5) }

      it "raises InvalidOtpError even when the correct code is submitted" do
        expect {
          described_class.confirm_reset(user.identifier, "123456", "newpassword1")
        }.to raise_error(Auth::PasswordResetService::InvalidOtpError, /locked/i)
      end

      it "does not update the password" do
        original_digest = user.password_digest
        described_class.confirm_reset(user.identifier, "123456", "newpassword1") rescue nil
        expect(user.reload.password_digest).to eq(original_digest)
      end
    end

    # -------------------------------------------------------------------------
    # Invalid new password
    # -------------------------------------------------------------------------
    context "when the new password is too short" do
      let(:user)      { create_user }
      let!(:otp_code) { create_otp_code(user) }

      it "raises InvalidPasswordError" do
        expect {
          described_class.confirm_reset(user.identifier, "123456", "short")
        }.to raise_error(Auth::PasswordResetService::InvalidPasswordError)
      end

      it "does not update the password digest" do
        original_digest = user.password_digest
        described_class.confirm_reset(user.identifier, "123456", "short") rescue nil
        expect(user.reload.password_digest).to eq(original_digest)
      end

      it "does not invalidate JWTs" do
        token = Auth::SessionService.issue_jwt(user)
        described_class.confirm_reset(user.identifier, "123456", "short") rescue nil
        expect { Auth::SessionService.verify_jwt(token) }.not_to raise_error
      end
    end
  end
end
