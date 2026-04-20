# frozen_string_literal: true

module Auth
  # Handles new user registration: validates identifier uniqueness, creates an
  # unverified {User} record, and triggers OTP delivery so the user can verify
  # their identifier.
  #
  # @example Register a new user with an email address
  #   service = Auth::RegistrationService.new
  #   user = service.register("user@example.com")
  #   # => #<User id=1 identifier="user@example.com" verified=false>
  #
  # @example Register with an optional password
  #   user = Auth::RegistrationService.new.register("+14155552671", password: "s3cur3pass")
  #
  # @raise [Auth::RegistrationService::IdentifierTakenError] if the identifier is already registered
  # @raise [Auth::RegistrationService::InvalidIdentifierError] if the identifier format is invalid
  class RegistrationService
    # Raised when the requested identifier is already registered.
    class IdentifierTakenError < StandardError; end

    # Raised when the identifier does not match a valid E.164 phone number or
    # RFC 5322 email address format.
    class InvalidIdentifierError < StandardError; end

    # Registers a new user with the given identifier.
    #
    # Steps:
    # 1. Checks uniqueness — raises {IdentifierTakenError} if already taken.
    # 2. Builds a {User} with +verified: false+ and the optional password.
    # 3. Validates the record — raises {InvalidIdentifierError} if invalid.
    # 4. Persists the user.
    # 5. Triggers OTP delivery via {Auth::OtpService#request_otp}.
    # 6. Returns the persisted user.
    #
    # @param identifier [String] a phone number (E.164) or email address (RFC 5322)
    # @param password [String, nil] optional password; stored as a bcrypt hash
    # @return [User] the newly created, unverified user
    # @raise [Auth::RegistrationService::IdentifierTakenError] if the identifier is already in use
    # @raise [Auth::RegistrationService::InvalidIdentifierError] if the identifier format is invalid
    def register(identifier, password: nil)
      if User.exists?(identifier: identifier)
        raise IdentifierTakenError, "#{identifier} is already registered"
      end

      user = User.new(identifier: identifier, verified: false)
      user.password = password if password.present?

      unless user.valid?
        raise InvalidIdentifierError, user.errors.full_messages.join(", ")
      end

      user.save!

      Auth::OtpService.new(user).request_otp

      user
    end
  end
end
