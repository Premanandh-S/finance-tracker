# frozen_string_literal: true

require "rails_helper"

RSpec.describe SavingsInstrument, type: :model do
  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  def valid_user
    User.create!(identifier: "+14155552671", password: "securepass")
  end

  def valid_attrs(overrides = {})
    {
      institution_name: "SBI",
      savings_identifier: "FD-2024-001",
      savings_type: "fd",
      principal_amount: 100_000_00,
      annual_interest_rate: 7.0,
      contribution_frequency: "one_time",
      start_date: Date.new(2024, 1, 15),
      maturity_date: Date.new(2026, 1, 15)
    }.merge(overrides)
  end

  def build_instrument(user, overrides = {})
    user.savings_instruments.build(valid_attrs(overrides))
  end

  def create_instrument(user, overrides = {})
    user.savings_instruments.create!(valid_attrs(overrides))
  end

  # ---------------------------------------------------------------------------
  # 1. Valid instrument
  # ---------------------------------------------------------------------------
  describe "valid savings instrument" do
    it "is valid with all required attributes (one_time)" do
      user = valid_user
      instrument = build_instrument(user)
      expect(instrument).to be_valid
    end

    it "is valid with a recurring frequency when recurring_amount is provided" do
      user = valid_user
      instrument = build_instrument(user,
        savings_type: "rd",
        contribution_frequency: "monthly",
        recurring_amount: 5_000_00)
      expect(instrument).to be_valid
    end

    it "is valid without a maturity_date" do
      user = valid_user
      instrument = build_instrument(user, maturity_date: nil)
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

    it "is invalid without savings_identifier" do
      user = valid_user
      instrument = build_instrument(user, savings_identifier: "")
      expect(instrument).not_to be_valid
      expect(instrument.errors[:savings_identifier]).to be_present
    end

    it "is invalid without start_date" do
      user = valid_user
      instrument = build_instrument(user, start_date: nil)
      expect(instrument).not_to be_valid
      expect(instrument.errors[:start_date]).to be_present
    end
  end

  # ---------------------------------------------------------------------------
  # 3. principal_amount validations
  # ---------------------------------------------------------------------------
  describe "principal_amount" do
    it "is invalid when principal_amount is zero" do
      user = valid_user
      instrument = build_instrument(user, principal_amount: 0)
      expect(instrument).not_to be_valid
      expect(instrument.errors[:principal_amount]).to be_present
    end

    it "is invalid when principal_amount is negative" do
      user = valid_user
      instrument = build_instrument(user, principal_amount: -1)
      expect(instrument).not_to be_valid
      expect(instrument.errors[:principal_amount]).to be_present
    end

    it "is invalid when principal_amount is a decimal" do
      user = valid_user
      instrument = build_instrument(user, principal_amount: 100.5)
      expect(instrument).not_to be_valid
      expect(instrument.errors[:principal_amount]).to be_present
    end

    it "is valid when principal_amount is a positive integer" do
      user = valid_user
      instrument = build_instrument(user, principal_amount: 1)
      expect(instrument).to be_valid
    end
  end

  # ---------------------------------------------------------------------------
  # 4. annual_interest_rate validations
  # ---------------------------------------------------------------------------
  describe "annual_interest_rate" do
    it "is invalid when annual_interest_rate is below 0" do
      user = valid_user
      instrument = build_instrument(user, annual_interest_rate: -0.1)
      expect(instrument).not_to be_valid
      expect(instrument.errors[:annual_interest_rate]).to be_present
    end

    it "is invalid when annual_interest_rate is above 100" do
      user = valid_user
      instrument = build_instrument(user, annual_interest_rate: 100.1)
      expect(instrument).not_to be_valid
      expect(instrument.errors[:annual_interest_rate]).to be_present
    end

    it "is valid when annual_interest_rate is exactly 0" do
      user = valid_user
      instrument = build_instrument(user, annual_interest_rate: 0)
      expect(instrument).to be_valid
    end

    it "is valid when annual_interest_rate is exactly 100" do
      user = valid_user
      instrument = build_instrument(user, annual_interest_rate: 100)
      expect(instrument).to be_valid
    end

    it "is valid when annual_interest_rate is within range" do
      user = valid_user
      instrument = build_instrument(user, annual_interest_rate: 7.5)
      expect(instrument).to be_valid
    end
  end

  # ---------------------------------------------------------------------------
  # 5. savings_type validations
  # ---------------------------------------------------------------------------
  describe "savings_type" do
    it "is invalid with an unrecognised savings_type" do
      user = valid_user
      instrument = build_instrument(user, savings_type: "bonds")
      expect(instrument).not_to be_valid
      expect(instrument.errors[:savings_type]).to be_present
    end

    it "is invalid with a blank savings_type" do
      user = valid_user
      instrument = build_instrument(user, savings_type: "")
      expect(instrument).not_to be_valid
      expect(instrument.errors[:savings_type]).to be_present
    end

    %w[fd rd other].each do |type|
      it "is valid with savings_type '#{type}'" do
        user = valid_user
        # Use one_time frequency so no recurring_amount is needed for fd/other;
        # rd uses monthly with a recurring_amount to satisfy the custom validation.
        if type == "rd"
          instrument = build_instrument(user,
            savings_type: type,
            contribution_frequency: "monthly",
            recurring_amount: 5_000_00)
        else
          instrument = build_instrument(user,
            savings_type: type,
            contribution_frequency: "one_time")
        end
        expect(instrument).to be_valid
      end
    end
  end

  # ---------------------------------------------------------------------------
  # 6. contribution_frequency validations
  # ---------------------------------------------------------------------------
  describe "contribution_frequency" do
    it "is invalid with an unrecognised contribution_frequency" do
      user = valid_user
      instrument = build_instrument(user, contribution_frequency: "weekly")
      expect(instrument).not_to be_valid
      expect(instrument.errors[:contribution_frequency]).to be_present
    end

    it "is invalid with a blank contribution_frequency" do
      user = valid_user
      instrument = build_instrument(user, contribution_frequency: "")
      expect(instrument).not_to be_valid
      expect(instrument.errors[:contribution_frequency]).to be_present
    end

    %w[one_time monthly quarterly annually].each do |freq|
      it "is valid with contribution_frequency '#{freq}'" do
        user = valid_user
        attrs = { contribution_frequency: freq }
        attrs[:recurring_amount] = 5_000_00 unless freq == "one_time"
        instrument = build_instrument(user, attrs)
        expect(instrument).to be_valid
      end
    end
  end

  # ---------------------------------------------------------------------------
  # 7. recurring_amount validations
  # ---------------------------------------------------------------------------
  describe "recurring_amount" do
    it "is valid when recurring_amount is nil for one_time frequency" do
      user = valid_user
      instrument = build_instrument(user, contribution_frequency: "one_time", recurring_amount: nil)
      expect(instrument).to be_valid
    end

    it "is invalid when recurring_amount is zero" do
      user = valid_user
      instrument = build_instrument(user,
        contribution_frequency: "monthly",
        recurring_amount: 0)
      expect(instrument).not_to be_valid
      expect(instrument.errors[:recurring_amount]).to be_present
    end

    it "is invalid when recurring_amount is negative" do
      user = valid_user
      instrument = build_instrument(user,
        contribution_frequency: "monthly",
        recurring_amount: -100)
      expect(instrument).not_to be_valid
      expect(instrument.errors[:recurring_amount]).to be_present
    end

    it "is invalid when recurring_amount is a decimal" do
      user = valid_user
      instrument = build_instrument(user,
        contribution_frequency: "monthly",
        recurring_amount: 100.5)
      expect(instrument).not_to be_valid
      expect(instrument.errors[:recurring_amount]).to be_present
    end
  end

  # ---------------------------------------------------------------------------
  # 8. Custom validation: recurring_amount_required_for_non_one_time
  # ---------------------------------------------------------------------------
  describe "recurring_amount_required_for_non_one_time" do
    %w[monthly quarterly annually].each do |freq|
      it "is invalid when contribution_frequency is '#{freq}' and recurring_amount is nil" do
        user = valid_user
        instrument = build_instrument(user,
          contribution_frequency: freq,
          recurring_amount: nil)
        expect(instrument).not_to be_valid
        expect(instrument.errors[:recurring_amount]).to include(
          "is required when contribution frequency is not one_time"
        )
      end
    end

    it "does not add the error when contribution_frequency is 'one_time'" do
      user = valid_user
      instrument = build_instrument(user,
        contribution_frequency: "one_time",
        recurring_amount: nil)
      expect(instrument).to be_valid
      expect(instrument.errors[:recurring_amount]).to be_empty
    end

    it "does not add the error when recurring_amount is present for a recurring frequency" do
      user = valid_user
      instrument = build_instrument(user,
        contribution_frequency: "monthly",
        recurring_amount: 5_000_00)
      expect(instrument).to be_valid
    end
  end

  # ---------------------------------------------------------------------------
  # 9. Custom validation: maturity_date_after_start_date
  # ---------------------------------------------------------------------------
  describe "maturity_date_after_start_date" do
    it "is invalid when maturity_date equals start_date" do
      user = valid_user
      date = Date.new(2024, 1, 15)
      instrument = build_instrument(user, start_date: date, maturity_date: date)
      expect(instrument).not_to be_valid
      expect(instrument.errors[:maturity_date]).to include("must be after the start date")
    end

    it "is invalid when maturity_date is before start_date" do
      user = valid_user
      instrument = build_instrument(user,
        start_date: Date.new(2024, 6, 1),
        maturity_date: Date.new(2024, 1, 1))
      expect(instrument).not_to be_valid
      expect(instrument.errors[:maturity_date]).to include("must be after the start date")
    end

    it "is valid when maturity_date is after start_date" do
      user = valid_user
      instrument = build_instrument(user,
        start_date: Date.new(2024, 1, 15),
        maturity_date: Date.new(2026, 1, 15))
      expect(instrument).to be_valid
    end

    it "is valid when maturity_date is nil" do
      user = valid_user
      instrument = build_instrument(user, maturity_date: nil)
      expect(instrument).to be_valid
    end
  end

  # ---------------------------------------------------------------------------
  # 10. Constants
  # ---------------------------------------------------------------------------
  describe "SAVINGS_TYPES" do
    it "contains exactly 'fd', 'rd', and 'other'" do
      expect(SavingsInstrument::SAVINGS_TYPES).to eq(%w[fd rd other])
    end

    it "is frozen" do
      expect(SavingsInstrument::SAVINGS_TYPES).to be_frozen
    end
  end

  describe "CONTRIBUTION_FREQUENCIES" do
    it "contains exactly 'one_time', 'monthly', 'quarterly', and 'annually'" do
      expect(SavingsInstrument::CONTRIBUTION_FREQUENCIES).to eq(%w[one_time monthly quarterly annually])
    end

    it "is frozen" do
      expect(SavingsInstrument::CONTRIBUTION_FREQUENCIES).to be_frozen
    end
  end

  # ---------------------------------------------------------------------------
  # 11. for_user scope
  # ---------------------------------------------------------------------------
  describe ".for_user scope" do
    it "returns only instruments belonging to the given user" do
      user_a = valid_user
      user_b = User.create!(identifier: "+14155559999", password: "securepass")

      create_instrument(user_a)
      create_instrument(user_b, savings_identifier: "FD-2024-002")

      result = SavingsInstrument.for_user(user_a)
      expect(result.count).to eq(1)
      expect(result.first.user).to eq(user_a)
    end

    it "returns an empty relation when the user has no savings instruments" do
      user = valid_user
      expect(SavingsInstrument.for_user(user)).to be_empty
    end

    it "returns all instruments for a user when they have multiple" do
      user = valid_user
      create_instrument(user, savings_identifier: "FD-001")
      create_instrument(user, savings_identifier: "FD-002")

      expect(SavingsInstrument.for_user(user).count).to eq(2)
    end
  end

  # ---------------------------------------------------------------------------
  # 12. Associations
  # ---------------------------------------------------------------------------
  describe "associations" do
    it "belongs to a user" do
      user = valid_user
      instrument = create_instrument(user)
      expect(instrument.user).to eq(user)
    end

    it "is destroyed when the owning user is destroyed" do
      user = valid_user
      instrument = create_instrument(user)
      instrument_id = instrument.id

      # Delete via SQL to avoid triggering other has_many associations that
      # may not yet have their model files in place.
      User.where(id: user.id).delete_all

      expect(SavingsInstrument.find_by(id: instrument_id)).to be_nil
    end
  end
end
