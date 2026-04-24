# frozen_string_literal: true

# Represents a person covered under an insurance policy.
# The member_identifier is optional — it is assigned by the insurer and may
# not be available at the time of data entry.
#
# @!attribute [rw] name
#   @return [String] the full name of the insured person
# @!attribute [rw] member_identifier
#   @return [String, nil] the identifier assigned by the insurer; optional
class InsuredMember < ApplicationRecord
  # Associations
  belongs_to :insurance_policy

  # Validations
  validates :name, presence: true
  # member_identifier is optional — assigned by the insurer
end
