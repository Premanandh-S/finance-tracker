# frozen_string_literal: true

# @!attribute [rw] user_id
#   @return [Integer] the ID of the associated user
# @!attribute [rw] code_digest
#   @return [String] bcrypt hash of the 6-digit OTP code
# @!attribute [rw] expires_at
#   @return [Time] timestamp when this OTP expires
# @!attribute [rw] used
#   @return [Boolean] whether this OTP has been consumed
# @!attribute [rw] failed_attempts
#   @return [Integer] number of consecutive failed verification attempts
class OtpCode < ApplicationRecord
  # ---------------------------------------------------------------------------
  # Associations
  # ---------------------------------------------------------------------------

  # @return [User] the user this OTP belongs to
  belongs_to :user

  # ---------------------------------------------------------------------------
  # Validations
  # ---------------------------------------------------------------------------

  validates :user_id,     presence: true
  validates :code_digest, presence: true
  validates :expires_at,  presence: true

  # ---------------------------------------------------------------------------
  # Scopes
  # ---------------------------------------------------------------------------

  # Returns OTP codes that are neither used nor expired.
  # @return [ActiveRecord::Relation<OtpCode>]
  scope :active,  -> { where(used: false).where("expires_at > ?", Time.current) }

  # Returns OTP codes whose expiry time has passed.
  # @return [ActiveRecord::Relation<OtpCode>]
  scope :expired, -> { where("expires_at <= ?", Time.current) }

  # Returns OTP codes that have been marked as used.
  # @return [ActiveRecord::Relation<OtpCode>]
  scope :used,    -> { where(used: true) }

  # ---------------------------------------------------------------------------
  # Instance Methods
  # ---------------------------------------------------------------------------

  # Checks whether this OTP has passed its expiry time.
  #
  # @return [Boolean] true if +expires_at+ is in the past or present
  def expired?
    expires_at <= Time.current
  end

  # Checks whether this OTP is still valid for verification.
  # An OTP is active when it has not been used and has not expired.
  #
  # @return [Boolean] true if the OTP is unused and unexpired
  def active?
    !used && !expired?
  end
end
