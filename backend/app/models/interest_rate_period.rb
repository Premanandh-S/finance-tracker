# frozen_string_literal: true

# @!attribute [rw] start_date
#   @return [Date] the date from which this rate period applies
# @!attribute [rw] end_date
#   @return [Date, nil] the date until which this rate period applies; nil means open-ended
# @!attribute [rw] annual_interest_rate
#   @return [BigDecimal] annual interest rate as a percentage (0–100)
#
# Represents a date-bounded interest rate for a floating-rate loan.
# A nil +end_date+ indicates the current, open-ended rate period.
class InterestRatePeriod < ApplicationRecord
  # Associations
  belongs_to :loan

  # Validations
  validates :start_date, presence: true
  validates :annual_interest_rate, numericality: {
    greater_than_or_equal_to: 0,
    less_than_or_equal_to: 100
  }
  # end_date is nullable — nil means "open-ended / current period"
end
