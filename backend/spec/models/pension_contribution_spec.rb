# frozen_string_literal: true

require "rails_helper"

RSpec.describe PensionContribution, type: :model do
  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  def valid_user
    User.create!(identifier: "+14155552671", password: "securepass")
  end

  def valid_instrument_attrs(overrides = {})
    {
      institution_name: "EPFO",
      pension_identifier: "EPF-2024-001",
      pension_type: "epf"
    }.merge(overrides)
  end

  def create_instrument(user, overrides = {})
    user.pension_instruments.create!(valid_instrument_attrs(overrides))
  end

  def valid_attrs(overrides = {})
    {
      contribution_date: Date.new(2024, 6, 1),
      amount: 180_000,
      contributor_type: "employee"
    }.merge(overrides)
  end

  def build_contribution(instrument, overrides = {})
    instrument.pension_contributions.build(valid_attrs(overrides))
  end

  def create_contribution(instrument, overrides = {})
    instrument.pension_contributions.create!(valid_attrs(overrides))
  end

  # ---------------------------------------------------------------------------
  # 1. Valid contribution
  # ---------------------------------------------------------------------------
  describe "valid contribution" do
    it "is valid with all required attributes" do
      user = valid_user
      instrument = create_instrument(user)
      contribution = build_contribution(instrument)
      expect(contribution).to be_valid
    end
  end

  # ---------------------------------------------------------------------------
  # 2. contribution_date presence validation
  # ---------------------------------------------------------------------------
  describe "contribution_date presence validation" do
    it "is invalid when contribution_date is nil" do
      user = valid_user
      instrument = create_instrument(user)
      contribution = build_contribution(instrument, contribution_date: nil)
      expect(contribution).not_to be_valid
      expect(contribution.errors[:contribution_date]).to be_present
    end
  end

  # ---------------------------------------------------------------------------
  # 3. amount validations
  # ---------------------------------------------------------------------------
  describe "amount validations" do
    it "is invalid when amount is zero" do
      user = valid_user
      instrument = create_instrument(user)
      contribution = build_contribution(instrument, amount: 0)
      expect(contribution).not_to be_valid
      expect(contribution.errors[:amount]).to be_present
    end

    it "is invalid when amount is negative" do
      user = valid_user
      instrument = create_instrument(user)
      contribution = build_contribution(instrument, amount: -100)
      expect(contribution).not_to be_valid
      expect(contribution.errors[:amount]).to be_present
    end

    it "is invalid when amount is a decimal" do
      user = valid_user
      instrument = create_instrument(user)
      contribution = build_contribution(instrument, amount: 100.5)
      expect(contribution).not_to be_valid
      expect(contribution.errors[:amount]).to be_present
    end

    it "is valid when amount is a positive integer" do
      user = valid_user
      instrument = create_instrument(user)
      contribution = build_contribution(instrument, amount: 180_000)
      expect(contribution).to be_valid
    end
  end

  # ---------------------------------------------------------------------------
  # 4. contributor_type inclusion validation
  # ---------------------------------------------------------------------------
  describe "contributor_type inclusion validation" do
    it "is invalid with an unrecognised contributor_type" do
      user = valid_user
      instrument = create_instrument(user)
      contribution = build_contribution(instrument, contributor_type: "company")
      expect(contribution).not_to be_valid
      expect(contribution.errors[:contributor_type]).to be_present
    end

    it "is invalid with a blank contributor_type" do
      user = valid_user
      instrument = create_instrument(user)
      contribution = build_contribution(instrument, contributor_type: "")
      expect(contribution).not_to be_valid
      expect(contribution.errors[:contributor_type]).to be_present
    end

    %w[employee employer self].each do |type|
      it "is valid with contributor_type '#{type}'" do
        user = valid_user
        instrument = create_instrument(user)
        contribution = build_contribution(instrument, contributor_type: type)
        expect(contribution).to be_valid
      end
    end
  end

  # ---------------------------------------------------------------------------
  # 5. CONTRIBUTOR_TYPES constant
  # ---------------------------------------------------------------------------
  describe "CONTRIBUTOR_TYPES" do
    it "contains exactly 'employee', 'employer', and 'self'" do
      expect(PensionContribution::CONTRIBUTOR_TYPES).to eq(%w[employee employer self])
    end

    it "is frozen" do
      expect(PensionContribution::CONTRIBUTOR_TYPES).to be_frozen
    end
  end

  # ---------------------------------------------------------------------------
  # 6. Associations
  # ---------------------------------------------------------------------------
  describe "associations" do
    it "belongs to a pension_instrument" do
      user = valid_user
      instrument = create_instrument(user)
      contribution = create_contribution(instrument)
      expect(contribution.pension_instrument).to eq(instrument)
    end

    it "is invalid without a pension_instrument" do
      contribution = PensionContribution.new(valid_attrs)
      expect(contribution).not_to be_valid
      expect(contribution.errors[:pension_instrument]).to be_present
    end
  end

  # ---------------------------------------------------------------------------
  # 7. Destroyed when parent pension_instrument is destroyed
  # ---------------------------------------------------------------------------
  describe "dependent destroy" do
    it "is destroyed when the parent pension_instrument is destroyed" do
      user = valid_user
      instrument = create_instrument(user)
      contribution = create_contribution(instrument)
      contribution_id = contribution.id

      instrument.destroy

      expect(PensionContribution.find_by(id: contribution_id)).to be_nil
    end

    it "all contributions are destroyed when the parent instrument is destroyed" do
      user = valid_user
      instrument = create_instrument(user)
      create_contribution(instrument, contribution_date: Date.new(2024, 5, 1))
      create_contribution(instrument, contribution_date: Date.new(2024, 6, 1))

      expect { instrument.destroy }.to change(PensionContribution, :count).by(-2)
    end
  end
end
