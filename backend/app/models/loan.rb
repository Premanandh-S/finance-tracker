# frozen_string_literal: true

# @!attribute [rw] institution_name
#   @return [String] the name of the lending institution
# @!attribute [rw] loan_identifier
#   @return [String] the loan number or identifier assigned by the institution
# @!attribute [rw] outstanding_balance
#   @return [Integer] remaining principal in the smallest currency unit (e.g. paise)
# @!attribute [rw] annual_interest_rate
#   @return [BigDecimal] annual interest rate as a percentage (0–100)
# @!attribute [rw] interest_rate_type
#   @return [String] either 'fixed' or 'floating'
# @!attribute [rw] monthly_payment
#   @return [Integer] fixed monthly payment amount in the smallest currency unit
# @!attribute [rw] payment_due_day
#   @return [Integer] day of month on which payment is due (1–28)
#
# Represents a loan liability belonging to a user.
# Monetary values are stored as integers in the smallest currency unit to avoid
# floating-point rounding errors.
class Loan < ApplicationRecord
  # Associations
  belongs_to :user
  has_many :interest_rate_periods, dependent: :destroy

  # Valid values for the interest_rate_type field.
  INTEREST_RATE_TYPES = %w[fixed floating].freeze

  # Validations
  validates :institution_name, presence: true
  validates :loan_identifier, presence: true
  validates :outstanding_balance, numericality: { only_integer: true, greater_than: 0 }
  validates :annual_interest_rate, numericality: {
    greater_than_or_equal_to: 0,
    less_than_or_equal_to: 100
  }
  validates :interest_rate_type, inclusion: { in: INTEREST_RATE_TYPES }
  validates :monthly_payment, numericality: { only_integer: true, greater_than: 0 }
  validates :payment_due_day, numericality: {
    only_integer: true,
    greater_than_or_equal_to: 1,
    less_than_or_equal_to: 28
  }

  validate :floating_rate_requires_at_least_one_period, on: :create

  # Scopes

  # Returns loans belonging to the given user.
  # @param user [User]
  # @return [ActiveRecord::Relation]
  scope :for_user, ->(user) { where(user: user) }

  private

  # Validates that a floating-rate loan has at least one interest_rate_period
  # at creation time. Fixed-rate loans are not subject to this constraint.
  # @return [void]
  def floating_rate_requires_at_least_one_period
    return unless interest_rate_type == "floating"
    return if interest_rate_periods.any?(&:new_record?) || interest_rate_periods.any?

    errors.add(:interest_rate_periods, "must have at least one period for a floating-rate loan")
  end
end
