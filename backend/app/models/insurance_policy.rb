# frozen_string_literal: true

# Represents an insurance policy (term, health, auto, or bike) belonging to a user.
# Monetary values (sum_assured, premium_amount) are stored as integers in the
# smallest currency unit (paise) to avoid floating-point rounding errors.
#
# @!attribute [rw] institution_name
#   @return [String] the name of the insurance provider
# @!attribute [rw] policy_number
#   @return [String] the policy number assigned by the insurer
# @!attribute [rw] policy_type
#   @return [String] the category of insurance; one of 'term', 'health', 'auto', 'bike'
# @!attribute [rw] sum_assured
#   @return [Integer] the coverage amount in the smallest currency unit (paise)
# @!attribute [rw] premium_amount
#   @return [Integer] the premium amount per payment period in paise
# @!attribute [rw] premium_frequency
#   @return [String] how often premiums are paid; one of 'monthly', 'quarterly', 'half_yearly', 'annually'
# @!attribute [rw] renewal_date
#   @return [Date] the date on which the policy is next due for renewal
# @!attribute [rw] policy_start_date
#   @return [Date, nil] the date on which the policy commenced; optional
# @!attribute [rw] notes
#   @return [String, nil] optional free-text notes about the policy
class InsurancePolicy < ApplicationRecord
  # Associations
  belongs_to :user
  has_many :insured_members, dependent: :destroy

  # Valid values for the policy_type field.
  POLICY_TYPES = %w[term health auto bike].freeze

  # Valid values for the premium_frequency field.
  PREMIUM_FREQUENCIES = %w[monthly quarterly half_yearly annually].freeze

  # Validations
  validates :institution_name,  presence: true
  validates :policy_number,     presence: true
  validates :policy_type,       inclusion: { in: POLICY_TYPES }
  validates :sum_assured,       numericality: { only_integer: true, greater_than: 0 }
  validates :premium_amount,    numericality: { only_integer: true, greater_than: 0 }
  validates :premium_frequency, inclusion: { in: PREMIUM_FREQUENCIES }
  validates :renewal_date,      presence: true

  validate :renewal_date_must_be_in_future, on: :create
  validate :renewal_date_must_be_in_future_on_update, on: :update

  # Scopes

  # Returns insurance policies belonging to the given user.
  # @param user [User]
  # @return [ActiveRecord::Relation]
  scope :for_user, ->(user) { where(user: user) }

  private

  # Validates that the renewal date is strictly in the future (after today).
  # This check runs on create and on update only when renewal_date has changed,
  # so that updates to other fields on an existing policy are not blocked.
  # Uses Date.current so that time-zone-aware test helpers (travel_to, freeze_time)
  # correctly influence the comparison.
  # @return [void]
  def renewal_date_must_be_in_future
    return unless renewal_date.present?
    return if renewal_date > Date.current

    errors.add(:renewal_date, "must be in the future")
  end

  # Delegates to renewal_date_must_be_in_future on update, but only when the
  # renewal_date attribute has actually changed. This prevents blocking updates
  # to other fields on policies whose stored renewal_date has since lapsed.
  # @return [void]
  def renewal_date_must_be_in_future_on_update
    return unless renewal_date_changed?

    renewal_date_must_be_in_future
  end
end
