# frozen_string_literal: true

require "rails_helper"

RSpec.describe PensionInstrument, type: :model do
  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  def valid_user
    User.create!(identifier: "+14155552671", password: "securepass")
  end

  def valid_attrs(overrides = {})
    {
      institution_name: "EPFO",
      pension_identifier: "EPF-2024-001",
      pension_type: "epf",
      contribution_start_date: Date.new(2020, 4, 1),
      maturity_date: Date.new(2045, 4, 1)
    }.merge(overrides)
  end

  def build_instrument(user, overrides = {})
    user.pension_instruments.build(valid_attrs(overrides))
  end

  def create_instrument(user, overrides = {})
    user.pension_instruments.create!(valid_attrs(overrides))
  end

  # ---------------------------------------------------------------------------
  # 1. Valid instrument
  # ---------------------------------------------------------------------------
  describe "valid pension instrument" do
    it "is valid with all required attributes" do
      user = valid_user
      instrument = build_instrument(user)
      expect(instrument).to be_valid
    end

    it "is valid without optional monthly_contribution_amount" do
      user = valid_user
      instrument = build_instrument(user, monthly_contribution_amount: nil)
      expect(instrument).to be_valid
    end

    it "is valid without optional contribution_start_date" do
      user = valid_user
      instrument = build_instrument(user, contribution_start_date: nil)
      expect(instrument).to be_valid
    end

    it "is valid without optional maturity_date" do
      user = valid_user
      instrument = build_instrument(user, maturity_date: nil)
      expect(instrument).to be_valid
    end

    it "is valid without optional notes" do
      user = valid_user
      instrument = build_instrument(user, notes: nil)
      expect(instrument).to be_valid
    end
  end

  # ---------------------------------------------------------------------------
  # 2. Presence validations
  # ---------------------------------------------------------------------------
  describe "presence validations" do
    it "is invalid without institution_name" do
      user = valid_user
      instrument = build_instrument(user, institution_name: "")
      expect(instrument).not_to be_valid
      expect(instrument.errors[:institution_name]).to be_present
    end

    it "is invalid without pension_identifier" do
      user = valid_user
      instrument = build_instrument(user, pension_identifier: "")
      expect(instrument).not_to be_valid
      expect(instrument.errors[:pension_identifier]).to be_present
    end
  end

  # ---------------------------------------------------------------------------
  # 3. pension_type validations
  # ---------------------------------------------------------------------------
  describe "pension_type" do
    it "is invalid with an unrecognised pension_type" do
      user = valid_user
      instrument = build_instrument(user, pension_type: "ppf")
      expect(instrument).not_to be_valid
      expect(instrument.errors[:pension_type]).to be_present
    end

    it "is invalid with a blank pension_type" do
      user = valid_user
      instrument = build_instrument(user, pension_type: "")
      expect(instrument).not_to be_valid
      expect(instrument.errors[:pension_type]).to be_present
    end

    %w[epf nps other].each do |type|
      it "is valid with pension_type '#{type}'" do
        user = valid_user
        instrument = build_instrument(user, pension_type: type)
        expect(instrument).to be_valid
      end
    end
  end

  # ---------------------------------------------------------------------------
  # 4. monthly_contribution_amount validations
  # ---------------------------------------------------------------------------
  describe "monthly_contribution_amount" do
    it "is valid when monthly_contribution_amount is nil" do
      user = valid_user
      instrument = build_instrument(user, monthly_contribution_amount: nil)
      expect(instrument).to be_valid
    end

    it "is invalid when monthly_contribution_amount is zero" do
      user = valid_user
      instrument = build_instrument(user, monthly_contribution_amount: 0)
      expect(instrument).not_to be_valid
      expect(instrument.errors[:monthly_contribution_amount]).to be_present
    end

    it "is invalid when monthly_contribution_amount is negative" do
      user = valid_user
      instrument = build_instrument(user, monthly_contribution_amount: -100)
      expect(instrument).not_to be_valid
      expect(instrument.errors[:monthly_contribution_amount]).to be_present
    end

    it "is invalid when monthly_contribution_amount is a decimal" do
      user = valid_user
      instrument = build_instrument(user, monthly_contribution_amount: 100.5)
      expect(instrument).not_to be_valid
      expect(instrument.errors[:monthly_contribution_amount]).to be_present
    end

    it "is valid when monthly_contribution_amount is a positive integer" do
      user = valid_user
      instrument = build_instrument(user, monthly_contribution_amount: 180_000)
      expect(instrument).to be_valid
    end
  end

  # ---------------------------------------------------------------------------
  # 5. Custom validation: maturity_date_after_contribution_start_date
  # ---------------------------------------------------------------------------
  describe "maturity_date_after_contribution_start_date" do
    it "is invalid when maturity_date is before contribution_start_date" do
      user = valid_user
      instrument = build_instrument(user,
        contribution_start_date: Date.new(2020, 4, 1),
        maturity_date: Date.new(2019, 1, 1))
      expect(instrument).not_to be_valid
      expect(instrument.errors[:maturity_date]).to include(
        "must be after the contribution start date"
      )
    end

    it "is invalid when maturity_date equals contribution_start_date" do
      user = valid_user
      date = Date.new(2020, 4, 1)
      instrument = build_instrument(user,
        contribution_start_date: date,
        maturity_date: date)
      expect(instrument).not_to be_valid
      expect(instrument.errors[:maturity_date]).to include(
        "must be after the contribution start date"
      )
    end

    it "is valid when maturity_date is after contribution_start_date" do
      user = valid_user
      instrument = build_instrument(user,
        contribution_start_date: Date.new(2020, 4, 1),
        maturity_date: Date.new(2045, 4, 1))
      expect(instrument).to be_valid
    end

    it "is valid when maturity_date is nil" do
      user = valid_user
      instrument = build_instrument(user, maturity_date: nil)
      expect(instrument).to be_valid
    end

    it "is valid when contribution_start_date is nil" do
      user = valid_user
      instrument = build_instrument(user, contribution_start_date: nil)
      expect(instrument).to be_valid
    end
  end

  # ---------------------------------------------------------------------------
  # 6. Constants
  # ---------------------------------------------------------------------------
  describe "PENSION_TYPES" do
    it "contains exactly 'epf', 'nps', and 'other'" do
      expect(PensionInstrument::PENSION_TYPES).to eq(%w[epf nps other])
    end

    it "is frozen" do
      expect(PensionInstrument::PENSION_TYPES).to be_frozen
    end
  end

  # ---------------------------------------------------------------------------
  # 7. for_user scope
  # ---------------------------------------------------------------------------
  describe ".for_user scope" do
    it "returns only instruments belonging to the given user" do
      user_a = valid_user
      user_b = User.create!(identifier: "+14155559999", password: "securepass")

      create_instrument(user_a)
      create_instrument(user_b, pension_identifier: "EPF-2024-002")

      result = PensionInstrument.for_user(user_a)
      expect(result.count).to eq(1)
      expect(result.first.user).to eq(user_a)
    end

    it "returns an empty relation when the user has no pension instruments" do
      user = valid_user
      expect(PensionInstrument.for_user(user)).to be_empty
    end

    it "returns all instruments for a user when they have multiple" do
      user = valid_user
      create_instrument(user, pension_identifier: "EPF-001")
      create_instrument(user, pension_identifier: "NPS-001", pension_type: "nps")

      expect(PensionInstrument.for_user(user).count).to eq(2)
    end
  end

  # ---------------------------------------------------------------------------
  # 8. Associations
  # ---------------------------------------------------------------------------
  describe "associations" do
    it "belongs to a user" do
      user = valid_user
      instrument = create_instrument(user)
      expect(instrument.user).to eq(user)
    end

    it "has many pension_contributions" do
      user = valid_user
      instrument = create_instrument(user)
      contribution = instrument.pension_contributions.create!(
        contribution_date: Date.new(2024, 6, 1),
        amount: 180_000,
        contributor_type: "employee"
      )
      expect(instrument.pension_contributions).to include(contribution)
    end

    it "destroys associated pension_contributions when the instrument is destroyed" do
      user = valid_user
      instrument = create_instrument(user)
      contribution = instrument.pension_contributions.create!(
        contribution_date: Date.new(2024, 6, 1),
        amount: 180_000,
        contributor_type: "employee"
      )
      contribution_id = contribution.id

      instrument.destroy
      expect(PensionContribution.find_by(id: contribution_id)).to be_nil
    end

    it "is destroyed when the owning user is destroyed" do
      user = valid_user
      instrument = create_instrument(user)
      instrument_id = instrument.id

      User.where(id: user.id).delete_all

      expect(PensionInstrument.find_by(id: instrument_id)).to be_nil
    end
  end
end
