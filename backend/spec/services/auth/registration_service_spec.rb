# frozen_string_literal: true

require "rails_helper"

RSpec.describe Auth::RegistrationService, "#register" do
  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------
  def create_user(overrides = {})
    User.create!({ identifier: "existing@example.com", password: "securepass" }.merge(overrides))
  end

  subject(:service) { described_class.new }

  let(:otp_service_double) { instance_double(Auth::OtpService, request_otp: "123456") }

  before do
    allow(Auth::OtpService).to receive(:new).and_return(otp_service_double)
  end

  # ---------------------------------------------------------------------------
  # 1. Returns the created user
  # ---------------------------------------------------------------------------
  describe "successful registration" do
    it "returns a User instance" do
      user = service.register("new@example.com", password: "securepass")
      expect(user).to be_a(User)
    end

    it "persists the user to the database" do
      expect { service.register("new@example.com", password: "securepass") }
        .to change { User.count }.by(1)
    end

    it "creates the user with verified: false" do
      user = service.register("new@example.com", password: "securepass")
      expect(user.verified).to be(false)
    end

    it "sets the correct identifier on the user" do
      user = service.register("new@example.com", password: "securepass")
      expect(user.identifier).to eq("new@example.com")
    end

    it "infers identifier_type as 'email' for an email address" do
      user = service.register("new@example.com", password: "securepass")
      expect(user.identifier_type).to eq("email")
    end

    it "infers identifier_type as 'phone' for an E.164 phone number" do
      user = service.register("+14155552671")
      expect(user.identifier_type).to eq("phone")
    end

    it "stores a bcrypt password digest when a password is provided" do
      user = service.register("new@example.com", password: "securepass")
      expect(user.password_digest).to be_present
      expect(user.password_digest).not_to eq("securepass")
    end

    it "creates a user without a password when none is provided" do
      user = service.register("+14155552671")
      expect(user.password_digest).to be_nil
    end
  end

  # ---------------------------------------------------------------------------
  # 2. OTP delivery is triggered
  # ---------------------------------------------------------------------------
  describe "OTP delivery" do
    it "calls Auth::OtpService#request_otp after creating the user" do
      service.register("new@example.com", password: "securepass")
      expect(otp_service_double).to have_received(:request_otp)
    end

    it "passes the created user to Auth::OtpService.new" do
      service.register("new@example.com", password: "securepass")
      created_user = User.find_by(identifier: "new@example.com")
      expect(Auth::OtpService).to have_received(:new).with(created_user)
    end
  end

  # ---------------------------------------------------------------------------
  # 3. Duplicate identifier raises IdentifierTakenError
  # ---------------------------------------------------------------------------
  describe "duplicate identifier" do
    before { create_user(identifier: "existing@example.com") }

    it "raises IdentifierTakenError" do
      expect { service.register("existing@example.com", password: "securepass") }
        .to raise_error(Auth::RegistrationService::IdentifierTakenError)
    end

    it "does not create a new user record" do
      expect { service.register("existing@example.com", password: "securepass") rescue nil }
        .not_to change { User.count }
    end

    it "does not trigger OTP delivery" do
      service.register("existing@example.com", password: "securepass") rescue nil
      expect(otp_service_double).not_to have_received(:request_otp)
    end

    it "includes the identifier in the error message" do
      expect { service.register("existing@example.com", password: "securepass") }
        .to raise_error(Auth::RegistrationService::IdentifierTakenError, /existing@example\.com/)
    end
  end

  # ---------------------------------------------------------------------------
  # 4. Invalid identifier raises InvalidIdentifierError
  # ---------------------------------------------------------------------------
  describe "invalid identifier" do
    it "raises InvalidIdentifierError for a plain string" do
      expect { service.register("not-an-identifier") }
        .to raise_error(Auth::RegistrationService::InvalidIdentifierError)
    end

    it "raises InvalidIdentifierError for a phone number without leading +" do
      expect { service.register("14155552671") }
        .to raise_error(Auth::RegistrationService::InvalidIdentifierError)
    end

    it "raises InvalidIdentifierError for an email missing the @ symbol" do
      expect { service.register("userexample.com") }
        .to raise_error(Auth::RegistrationService::InvalidIdentifierError)
    end

    it "does not persist a user when the identifier is invalid" do
      expect { service.register("bad-identifier") rescue nil }
        .not_to change { User.count }
    end

    it "does not trigger OTP delivery when the identifier is invalid" do
      service.register("bad-identifier") rescue nil
      expect(otp_service_double).not_to have_received(:request_otp)
    end

    it "includes a descriptive message in the error" do
      expect { service.register("bad-identifier") }
        .to raise_error(Auth::RegistrationService::InvalidIdentifierError, /identifier/i)
    end
  end

  # ---------------------------------------------------------------------------
  # 5. Password validation is enforced
  # ---------------------------------------------------------------------------
  describe "password validation" do
    it "raises InvalidIdentifierError when the password is too short" do
      expect { service.register("new@example.com", password: "short") }
        .to raise_error(Auth::RegistrationService::InvalidIdentifierError, /password/i)
    end

    it "does not persist a user when the password is too short" do
      expect { service.register("new@example.com", password: "short") rescue nil }
        .not_to change { User.count }
    end
  end
end
