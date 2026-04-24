# frozen_string_literal: true

# @!attribute [rw] identifier
#   @return [String] the user's phone number (E.164) or email address (RFC 5322)
# @!attribute [rw] identifier_type
#   @return [String] either 'phone' or 'email', derived automatically from identifier
# @!attribute [rw] password_digest
#   @return [String, nil] bcrypt hash of the user's password; nil for OTP-only users
# @!attribute [rw] verified
#   @return [Boolean] whether the user has completed OTP verification
# @!attribute [rw] password_failed_attempts
#   @return [Integer] consecutive failed password login attempts
# @!attribute [rw] password_locked_until
#   @return [DateTime, nil] timestamp until which password login is locked
#
# Represents a registered user who authenticates via phone or email.
# Passwords are stored as bcrypt hashes via +has_secure_password+.
# The +identifier_type+ is inferred automatically before validation.
class User < ApplicationRecord
  has_secure_password validations: false

  # Associations
  has_many :otp_codes, dependent: :destroy
  has_many :otp_request_logs, dependent: :destroy
  has_many :loans, dependent: :destroy
  has_many :savings_instruments,  dependent: :destroy
  has_many :insurance_policies,   dependent: :destroy
  has_many :pension_instruments,  dependent: :destroy

  # E.164: starts with +, followed by 7–15 digits
  PHONE_REGEX = /\A\+[1-9]\d{6,14}\z/

  # RFC 5322-compatible email regex (Ruby stdlib)
  EMAIL_REGEX = URI::MailTo::EMAIL_REGEXP

  # Callbacks
  before_validation :infer_identifier_type

  # Validations
  validates :identifier, presence: true, uniqueness: { case_sensitive: false }
  validates :identifier_type, presence: true, inclusion: { in: %w[phone email] }
  validates :password, length: { minimum: 8, message: "must be at least 8 characters" },
                       if: -> { password.present? }

  validate :identifier_format

  # @return [Boolean] true if the user authenticates via phone number
  def phone?
    identifier_type == "phone"
  end

  # @return [Boolean] true if the user authenticates via email address
  def email?
    identifier_type == "email"
  end

  private

  # Infers and sets +identifier_type+ based on the format of +identifier+.
  # Called automatically before validation.
  # @return [void]
  def infer_identifier_type
    return if identifier.blank?

    self.identifier_type =
      if identifier.match?(PHONE_REGEX)
        "phone"
      elsif identifier.match?(EMAIL_REGEX)
        "email"
      end
  end

  # Validates that +identifier+ matches either E.164 phone or RFC 5322 email format.
  # Adds an error if neither format matches.
  # @return [void]
  def identifier_format
    return if identifier.blank?

    unless identifier.match?(PHONE_REGEX) || identifier.match?(EMAIL_REGEX)
      errors.add(:identifier, "must be a valid E.164 phone number (e.g. +14155552671) or RFC 5322 email address")
    end
  end
end
