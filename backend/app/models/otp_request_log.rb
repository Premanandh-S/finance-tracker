# frozen_string_literal: true

# @!attribute [rw] user_id
#   @return [Integer] the ID of the associated user
# @!attribute [rw] requested_at
#   @return [Time] timestamp when the OTP was requested
#
# Records each OTP request for a user, used to enforce the rate limit
# of 5 requests per 60-minute window.
class OtpRequestLog < ApplicationRecord
  # ---------------------------------------------------------------------------
  # Associations
  # ---------------------------------------------------------------------------

  # @return [User] the user who made this OTP request
  belongs_to :user

  # ---------------------------------------------------------------------------
  # Validations
  # ---------------------------------------------------------------------------

  validates :user_id,      presence: true
  validates :requested_at, presence: true

  # ---------------------------------------------------------------------------
  # Callbacks
  # ---------------------------------------------------------------------------

  before_validation :set_requested_at, on: :create

  private

  # Sets +requested_at+ to the current time if not already set.
  # @return [void]
  def set_requested_at
    self.requested_at ||= Time.current
  end
end
