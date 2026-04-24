# frozen_string_literal: true

# @!attribute [rw] institution_name
#   @return [String] the name of the institution managing the pension instrument
# @!attribute [rw] pension_identifier
#   @return [String] the account or member number assigned by the institution
# @!attribute [rw] pension_type
#   @return [String] the category of pension product; one of 'epf', 'nps', 'other'
# @!attribute [rw] monthly_contribution_amount
#   @return [Integer, nil] the regular monthly contribution in the smallest currency unit (paise);
#     nil when contributions are irregular or unknown
# @!attribute [rw] contribution_start_date
#   @return [Date, nil] the date on which contributions began; nil if unknown
# @!attribute [rw] maturity_date
#   @return [Date, nil] the date on which the pension instrument matures or the member retires;
#     nil if open-ended
# @!attribute [rw] notes
#   @return [String, nil] optional free-text notes about the instrument
#
# Represents a pension instrument (EPF, NPS, or other) belonging to a user.
# Monetary values are stored as integers in the smallest currency unit (paise)
# to avoid floating-point rounding errors.
# The total corpus is always computed at query time from associated
# PensionContribution records and is never stored as a column.
class PensionInstrument < ApplicationRecord
  # Associations
  belongs_to :user
  has_many :pension_contributions, dependent: :destroy

  # Valid values for the pension_type field.
  PENSION_TYPES = %w[epf nps other].freeze

  # Validations
  validates :institution_name,   presence: true
  validates :pension_identifier, presence: true
  validates :pension_type,       inclusion: { in: PENSION_TYPES }
  validates :monthly_contribution_amount,
            numericality: { only_integer: true, greater_than: 0 },
            allow_nil: true

  validate :maturity_date_after_contribution_start_date

  # Scopes

  # Returns pension instruments belonging to the given user.
  # @param user [User]
  # @return [ActiveRecord::Relation]
  scope :for_user, ->(user) { where(user: user) }

  private

  # Validates that the maturity date, when present, is strictly after the
  # contribution start date.
  # @return [void]
  def maturity_date_after_contribution_start_date
    return unless maturity_date.present? && contribution_start_date.present?
    return if maturity_date > contribution_start_date

    errors.add(:maturity_date, "must be after the contribution start date")
  end
end
