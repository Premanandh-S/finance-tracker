# frozen_string_literal: true

# @!attribute [rw] contribution_date
#   @return [Date] the date on which the contribution was made
# @!attribute [rw] amount
#   @return [Integer] the contribution amount in the smallest currency unit (paise)
# @!attribute [rw] contributor_type
#   @return [String] who made the contribution; one of 'employee', 'employer', 'self'
#
# Represents a single contribution record for a PensionInstrument.
# Monetary values are stored as integers in the smallest currency unit (paise)
# to avoid floating-point rounding errors.
class PensionContribution < ApplicationRecord
  # Associations
  belongs_to :pension_instrument

  # Valid values for the contributor_type field.
  CONTRIBUTOR_TYPES = %w[employee employer self].freeze

  # Validations
  validates :contribution_date, presence: true
  validates :amount,            numericality: { only_integer: true, greater_than: 0 }
  validates :contributor_type,  inclusion: { in: CONTRIBUTOR_TYPES }
end
