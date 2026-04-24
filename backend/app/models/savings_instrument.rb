# frozen_string_literal: true

# @!attribute [rw] institution_name
#   @return [String] the name of the financial institution holding the savings instrument
# @!attribute [rw] savings_identifier
#   @return [String] the account or certificate number assigned by the institution
# @!attribute [rw] savings_type
#   @return [String] the category of savings product; one of 'fd', 'rd', 'other'
# @!attribute [rw] principal_amount
#   @return [Integer] the initial deposit amount in the smallest currency unit (paise)
# @!attribute [rw] annual_interest_rate
#   @return [BigDecimal] the annual interest rate as a percentage (0–100)
# @!attribute [rw] contribution_frequency
#   @return [String] how often contributions are made; one of 'one_time', 'monthly', 'quarterly', 'annually'
# @!attribute [rw] start_date
#   @return [Date] the date on which the savings instrument was opened
# @!attribute [rw] maturity_date
#   @return [Date, nil] the date on which the instrument matures; nil if open-ended
# @!attribute [rw] recurring_amount
#   @return [Integer, nil] the periodic contribution amount in paise; required when contribution_frequency is not 'one_time'
# @!attribute [rw] notes
#   @return [String, nil] optional free-text notes about the instrument
#
# Represents a savings instrument (FD, RD, or other) belonging to a user.
# Monetary values are stored as integers in the smallest currency unit (paise)
# to avoid floating-point rounding errors.
class SavingsInstrument < ApplicationRecord
  # Associations
  belongs_to :user

  # Valid values for the savings_type field.
  SAVINGS_TYPES = %w[fd rd other].freeze

  # Valid values for the contribution_frequency field.
  CONTRIBUTION_FREQUENCIES = %w[one_time monthly quarterly annually].freeze

  # Validations
  validates :institution_name,       presence: true
  validates :savings_identifier,     presence: true
  validates :savings_type,           inclusion: { in: SAVINGS_TYPES }
  validates :principal_amount,       numericality: { only_integer: true, greater_than: 0 }
  validates :annual_interest_rate,   numericality: {
    greater_than_or_equal_to: 0,
    less_than_or_equal_to: 100
  }
  validates :contribution_frequency, inclusion: { in: CONTRIBUTION_FREQUENCIES }
  validates :start_date,             presence: true
  validates :recurring_amount,       numericality: { only_integer: true, greater_than: 0 },
                                     allow_nil: true

  validate :recurring_amount_required_for_non_one_time
  validate :maturity_date_after_start_date

  # Scopes

  # Returns savings instruments belonging to the given user.
  # @param user [User]
  # @return [ActiveRecord::Relation]
  scope :for_user, ->(user) { where(user: user) }

  private

  # Validates that a recurring amount is provided whenever the contribution
  # frequency is not 'one_time'. One-time savings instruments do not require
  # a recurring amount.
  # @return [void]
  def recurring_amount_required_for_non_one_time
    return if contribution_frequency == "one_time"
    return if recurring_amount.present?

    errors.add(:recurring_amount, "is required when contribution frequency is not one_time")
  end

  # Validates that the maturity date, when present, is strictly after the
  # start date.
  # @return [void]
  def maturity_date_after_start_date
    return unless maturity_date.present? && start_date.present?
    return if maturity_date > start_date

    errors.add(:maturity_date, "must be after the start date")
  end
end
