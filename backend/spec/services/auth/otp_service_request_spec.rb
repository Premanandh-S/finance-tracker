# frozen_string_literal: true

require "rails_helper"

RSpec.describe Auth::OtpService, "#request_otp" do
  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------
  def create_user(overrides = {})
    User.create!({ identifier: "user@example.com", password: "securepass" }.merge(overrides))
  end

  def create_otp_code(user, overrides = {})
    OtpCode.create!({
      user:        user,
      code_digest: BCrypt::Password.create("123456"),
      expires_at:  10.minutes.from_now,
      used:        false
    }.merge(overrides))
  end

  def create_otp_request_log(user, overrides = {})
    OtpRequestLog.create!({
      user:         user,
      requested_at: Time.current
    }.merge(overrides))
  end

  let(:user) { create_user }
  let(:delivery_double) { instance_double(Auth::OtpDeliveryService, deliver: nil) }

  before do
    allow(Auth::OtpDeliveryService).to receive(:new).with(user).and_return(delivery_double)
  end

  subject(:service) { described_class.new(user) }

  # ---------------------------------------------------------------------------
  # 1. Returns a 6-digit numeric string
  # ---------------------------------------------------------------------------
  describe "OTP format" do
    it "returns a 6-character string" do
      code = service.request_otp
      expect(code.length).to eq(6)
    end

    it "returns a string consisting entirely of digits" do
      code = service.request_otp
      expect(code).to match(/\A\d{6}\z/)
    end

    it "zero-pads codes shorter than 6 digits" do
      allow(SecureRandom).to receive(:random_number).with(1_000_000).and_return(42)
      code = service.request_otp
      expect(code).to eq("000042")
    end
  end

  # ---------------------------------------------------------------------------
  # 2. Creates an OtpCode record with a bcrypt digest
  # ---------------------------------------------------------------------------
  describe "OtpCode persistence" do
    it "creates exactly one OtpCode record" do
      expect { service.request_otp }.to change { user.otp_codes.count }.by(1)
    end

    it "stores a bcrypt digest, not the plaintext code" do
      code = service.request_otp
      otp_record = user.otp_codes.last
      expect(otp_record.code_digest).not_to eq(code)
      expect(BCrypt::Password.new(otp_record.code_digest)).to eq(code)
    end

    it "sets expires_at approximately 10 minutes from now" do
      freeze_time do
        service.request_otp
        otp_record = user.otp_codes.last
        expect(otp_record.expires_at).to be_within(1.second).of(10.minutes.from_now)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # 3. Invalidates prior active OTP
  # ---------------------------------------------------------------------------
  describe "prior OTP invalidation" do
    it "marks the previous active OTP as used" do
      prior_otp = create_otp_code(user, used: false, expires_at: 5.minutes.from_now)
      service.request_otp
      expect(prior_otp.reload.used).to be(true)
    end

    it "does not affect already-used OTPs" do
      already_used = create_otp_code(user, used: true, expires_at: 5.minutes.from_now)
      service.request_otp
      expect(already_used.reload.used).to be(true)
    end

    it "does not affect expired OTPs" do
      expired_otp = create_otp_code(user, used: false, expires_at: 1.minute.ago)
      service.request_otp
      expect(expired_otp.reload.used).to be(false)
    end
  end

  # ---------------------------------------------------------------------------
  # 4. Raises RateLimitError on 6th request within 60 minutes
  # ---------------------------------------------------------------------------
  describe "rate limiting" do
    it "raises RateLimitError when 5 requests already exist in the window" do
      5.times { create_otp_request_log(user, requested_at: 30.minutes.ago) }
      expect { service.request_otp }.to raise_error(Auth::OtpService::RateLimitError)
    end

    it "does not raise on the 5th request (4 prior logs)" do
      4.times { create_otp_request_log(user, requested_at: 30.minutes.ago) }
      expect { service.request_otp }.not_to raise_error
    end

    it "does not count requests outside the 60-minute window" do
      5.times { create_otp_request_log(user, requested_at: 61.minutes.ago) }
      expect { service.request_otp }.not_to raise_error
    end

    it "raises RateLimitError with a descriptive message" do
      5.times { create_otp_request_log(user, requested_at: 1.minute.ago) }
      expect { service.request_otp }.to raise_error(
        Auth::OtpService::RateLimitError,
        /rate limit|limit exceeded/i
      )
    end
  end

  # ---------------------------------------------------------------------------
  # 5. Logs the request in OtpRequestLog
  # ---------------------------------------------------------------------------
  describe "request logging" do
    it "creates an OtpRequestLog entry" do
      expect { service.request_otp }.to change { user.otp_request_logs.count }.by(1)
    end

    it "records requested_at close to the current time" do
      freeze_time do
        service.request_otp
        log = user.otp_request_logs.last
        expect(log.requested_at).to be_within(1.second).of(Time.current)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Delivery integration
  # ---------------------------------------------------------------------------
  describe "OTP delivery" do
    it "calls OtpDeliveryService#deliver with the plaintext code" do
      code = service.request_otp
      expect(delivery_double).to have_received(:deliver).with(code)
    end

    it "raises DeliveryError when OtpDeliveryService raises DeliveryError" do
      allow(delivery_double).to receive(:deliver)
        .and_raise(Auth::OtpDeliveryService::DeliveryError, "SMS failed")

      expect { service.request_otp }.to raise_error(Auth::OtpService::DeliveryError, "SMS failed")
    end

    it "does not log the request when delivery fails" do
      allow(delivery_double).to receive(:deliver)
        .and_raise(Auth::OtpDeliveryService::DeliveryError, "SMS failed")

      expect { service.request_otp rescue nil }.not_to change { user.otp_request_logs.count }
    end
  end
end

# ===========================================================================
# verify_otp
# ===========================================================================
RSpec.describe Auth::OtpService, "#verify_otp" do
  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------
  def create_user(overrides = {})
    User.create!({ identifier: "verify@example.com", password: "securepass" }.merge(overrides))
  end

  def create_otp_code(user, plaintext_code: "123456", overrides: {})
    OtpCode.create!({
      user:            user,
      code_digest:     BCrypt::Password.create(plaintext_code),
      expires_at:      10.minutes.from_now,
      used:            false,
      failed_attempts: 0
    }.merge(overrides))
  end

  let(:user) { create_user }

  subject(:service) { described_class.new(user) }

  # ---------------------------------------------------------------------------
  # 1. Correct code returns true and marks OTP used
  # ---------------------------------------------------------------------------
  describe "successful verification" do
    it "returns true when the correct code is submitted" do
      create_otp_code(user)
      expect(service.verify_otp("123456")).to be(true)
    end

    it "marks the OTP record as used after successful verification" do
      otp = create_otp_code(user)
      service.verify_otp("123456")
      expect(otp.reload.used).to be(true)
    end

    it "does not increment failed_attempts on success" do
      otp = create_otp_code(user)
      service.verify_otp("123456")
      expect(otp.reload.failed_attempts).to eq(0)
    end
  end

  # ---------------------------------------------------------------------------
  # 2. Wrong code raises InvalidOtpError and increments failed_attempts
  # ---------------------------------------------------------------------------
  describe "wrong code" do
    it "raises InvalidOtpError when the submitted code does not match" do
      create_otp_code(user)
      expect { service.verify_otp("000000") }
        .to raise_error(Auth::OtpService::InvalidOtpError)
    end

    it "increments failed_attempts by 1 on each wrong attempt" do
      otp = create_otp_code(user)
      service.verify_otp("000000") rescue nil
      expect(otp.reload.failed_attempts).to eq(1)

      service.verify_otp("111111") rescue nil
      expect(otp.reload.failed_attempts).to eq(2)
    end

    it "does not mark the OTP as used on a wrong attempt" do
      otp = create_otp_code(user)
      service.verify_otp("000000") rescue nil
      expect(otp.reload.used).to be(false)
    end
  end

  # ---------------------------------------------------------------------------
  # 3. Expired OTP raises InvalidOtpError
  # ---------------------------------------------------------------------------
  describe "expired OTP" do
    it "raises InvalidOtpError when the OTP has expired" do
      create_otp_code(user, overrides: { expires_at: 1.minute.ago })
      expect { service.verify_otp("123456") }
        .to raise_error(Auth::OtpService::InvalidOtpError)
    end

    it "raises InvalidOtpError when the OTP was used" do
      create_otp_code(user, overrides: { used: true })
      expect { service.verify_otp("123456") }
        .to raise_error(Auth::OtpService::InvalidOtpError)
    end

    it "raises InvalidOtpError when no OTP record exists at all" do
      expect { service.verify_otp("123456") }
        .to raise_error(Auth::OtpService::InvalidOtpError)
    end
  end

  # ---------------------------------------------------------------------------
  # 4. OTP expiry timing — expires after exactly 10 minutes
  # ---------------------------------------------------------------------------
  describe "OTP expiry timing" do
    it "is valid just before the 10-minute mark" do
      freeze_time do
        create_otp_code(user, overrides: { expires_at: 10.minutes.from_now })
      end
      travel 9.minutes do
        expect(service.verify_otp("123456")).to be(true)
      end
    end

    it "is invalid at exactly the 10-minute mark" do
      freeze_time do
        create_otp_code(user, overrides: { expires_at: 10.minutes.from_now })
      end
      travel 10.minutes do
        expect { service.verify_otp("123456") }
          .to raise_error(Auth::OtpService::InvalidOtpError)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # 5. Lockout after 5 consecutive failed attempts
  # ---------------------------------------------------------------------------
  describe "lockout after 5 failed attempts" do
    it "raises LockedError when failed_attempts has reached OTP_MAX_ATTEMPTS (5)" do
      create_otp_code(user, overrides: { failed_attempts: 5 })
      expect { service.verify_otp("123456") }
        .to raise_error(Auth::OtpService::LockedError)
    end

    it "raises LockedError even when the correct code is submitted after lockout" do
      create_otp_code(user, overrides: { failed_attempts: 5 })
      expect { service.verify_otp("123456") }
        .to raise_error(Auth::OtpService::LockedError)
    end

    it "does not raise LockedError when failed_attempts is 4 (one below threshold)" do
      create_otp_code(user, overrides: { failed_attempts: 4 })
      # 5th attempt with wrong code should raise InvalidOtpError, not LockedError
      expect { service.verify_otp("000000") }
        .to raise_error(Auth::OtpService::InvalidOtpError)
    end

    it "raises LockedError on the 6th attempt (5 prior failures)" do
      otp = create_otp_code(user)

      # 5 failed attempts
      5.times { service.verify_otp("000000") rescue nil }
      expect(otp.reload.failed_attempts).to eq(5)

      # 6th attempt — should be locked
      expect { service.verify_otp("123456") }
        .to raise_error(Auth::OtpService::LockedError)
    end

    it "includes a descriptive message in the LockedError" do
      create_otp_code(user, overrides: { failed_attempts: 5 })
      expect { service.verify_otp("123456") }
        .to raise_error(Auth::OtpService::LockedError, /locked/i)
    end
  end

  # ---------------------------------------------------------------------------
  # 6. Prior OTP invalidated — first OTP rejected after second is issued
  # ---------------------------------------------------------------------------
  describe "prior OTP invalidation on re-request" do
    let(:delivery_double) { instance_double(Auth::OtpDeliveryService, deliver: nil) }

    before do
      allow(Auth::OtpDeliveryService).to receive(:new).with(user).and_return(delivery_double)
    end

    it "rejects the first OTP after a second OTP has been requested" do
      # Issue first OTP
      first_code = service.request_otp

      # Request a second OTP (invalidates the first)
      service.request_otp

      # First code should now be invalid (its record was marked used)
      expect { service.verify_otp(first_code) }
        .to raise_error(Auth::OtpService::InvalidOtpError)
    end
  end
end
