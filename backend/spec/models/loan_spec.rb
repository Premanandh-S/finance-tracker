# frozen_string_literal: true

require "rails_helper"

RSpec.describe Loan, type: :model do
  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  def valid_user
    User.create!(identifier: "+14155552671", password: "securepass")
  end

  def valid_loan_attrs(overrides = {})
    {
      institution_name: "HDFC Bank",
      loan_identifier: "HL-2024-001",
      outstanding_balance: 250_000_00,
      annual_interest_rate: 8.5,
      interest_rate_type: "fixed",
      monthly_payment: 25_000_00,
      payment_due_day: 5
    }.merge(overrides)
  end

  def build_loan(user, overrides = {})
    user.loans.build(valid_loan_attrs(overrides))
  end

  def create_loan(user, overrides = {})
    user.loans.create!(valid_loan_attrs(overrides))
  end

  # ---------------------------------------------------------------------------
  # 1. Valid loan
  # ---------------------------------------------------------------------------
  describe "valid loan" do
    it "is valid with all required attributes" do
      user = valid_user
      loan = build_loan(user)
      expect(loan).to be_valid
    end
  end

  # ---------------------------------------------------------------------------
  # 2. outstanding_balance validations
  # ---------------------------------------------------------------------------
  describe "outstanding_balance" do
    it "is invalid when outstanding_balance is zero" do
      user = valid_user
      loan = build_loan(user, outstanding_balance: 0)
      expect(loan).not_to be_valid
      expect(loan.errors[:outstanding_balance]).to be_present
    end

    it "is invalid when outstanding_balance is negative" do
      user = valid_user
      loan = build_loan(user, outstanding_balance: -1)
      expect(loan).not_to be_valid
      expect(loan.errors[:outstanding_balance]).to be_present
    end

    it "is invalid when outstanding_balance is a decimal" do
      user = valid_user
      loan = build_loan(user, outstanding_balance: 100.5)
      expect(loan).not_to be_valid
      expect(loan.errors[:outstanding_balance]).to be_present
    end

    it "is valid when outstanding_balance is a positive integer" do
      user = valid_user
      loan = build_loan(user, outstanding_balance: 1)
      expect(loan).to be_valid
    end
  end

  # ---------------------------------------------------------------------------
  # 3. annual_interest_rate validations
  # ---------------------------------------------------------------------------
  describe "annual_interest_rate" do
    it "is invalid when annual_interest_rate is below 0" do
      user = valid_user
      loan = build_loan(user, annual_interest_rate: -0.1)
      expect(loan).not_to be_valid
      expect(loan.errors[:annual_interest_rate]).to be_present
    end

    it "is invalid when annual_interest_rate is above 100" do
      user = valid_user
      loan = build_loan(user, annual_interest_rate: 100.1)
      expect(loan).not_to be_valid
      expect(loan.errors[:annual_interest_rate]).to be_present
    end

    it "is valid when annual_interest_rate is exactly 0" do
      user = valid_user
      loan = build_loan(user, annual_interest_rate: 0)
      expect(loan).to be_valid
    end

    it "is valid when annual_interest_rate is exactly 100" do
      user = valid_user
      loan = build_loan(user, annual_interest_rate: 100)
      expect(loan).to be_valid
    end

    it "is valid when annual_interest_rate is within range" do
      user = valid_user
      loan = build_loan(user, annual_interest_rate: 8.5)
      expect(loan).to be_valid
    end
  end

  # ---------------------------------------------------------------------------
  # 4. payment_due_day validations
  # ---------------------------------------------------------------------------
  describe "payment_due_day" do
    it "is invalid when payment_due_day is 0" do
      user = valid_user
      loan = build_loan(user, payment_due_day: 0)
      expect(loan).not_to be_valid
      expect(loan.errors[:payment_due_day]).to be_present
    end

    it "is invalid when payment_due_day is 29" do
      user = valid_user
      loan = build_loan(user, payment_due_day: 29)
      expect(loan).not_to be_valid
      expect(loan.errors[:payment_due_day]).to be_present
    end

    it "is invalid when payment_due_day is negative" do
      user = valid_user
      loan = build_loan(user, payment_due_day: -1)
      expect(loan).not_to be_valid
      expect(loan.errors[:payment_due_day]).to be_present
    end

    it "is valid when payment_due_day is 1" do
      user = valid_user
      loan = build_loan(user, payment_due_day: 1)
      expect(loan).to be_valid
    end

    it "is valid when payment_due_day is 28" do
      user = valid_user
      loan = build_loan(user, payment_due_day: 28)
      expect(loan).to be_valid
    end
  end

  # ---------------------------------------------------------------------------
  # 5. interest_rate_type validations
  # ---------------------------------------------------------------------------
  describe "interest_rate_type" do
    it "is invalid with an unrecognised interest_rate_type" do
      user = valid_user
      loan = build_loan(user, interest_rate_type: "variable")
      expect(loan).not_to be_valid
      expect(loan.errors[:interest_rate_type]).to be_present
    end

    it "is invalid with a blank interest_rate_type" do
      user = valid_user
      loan = build_loan(user, interest_rate_type: "")
      expect(loan).not_to be_valid
      expect(loan.errors[:interest_rate_type]).to be_present
    end

    it "is valid with 'fixed'" do
      user = valid_user
      loan = build_loan(user, interest_rate_type: "fixed")
      expect(loan).to be_valid
    end

    it "is valid with 'floating'" do
      user = valid_user
      loan = build_loan(user, interest_rate_type: "floating")
      # Build with a nested rate period so the floating validation passes
      loan.interest_rate_periods.build(
        start_date: Date.today,
        annual_interest_rate: 8.5
      )
      expect(loan).to be_valid
    end
  end

  # ---------------------------------------------------------------------------
  # 6. Floating-rate loan requires at least one interest_rate_period on create
  # ---------------------------------------------------------------------------
  describe "floating_rate_requires_at_least_one_period" do
    it "is invalid on create when floating-rate loan has no interest_rate_periods" do
      user = valid_user
      loan = build_loan(user, interest_rate_type: "floating")
      expect(loan).not_to be_valid
      expect(loan.errors[:interest_rate_periods]).to be_present
    end

    it "is valid on create when floating-rate loan has at least one interest_rate_period" do
      user = valid_user
      loan = build_loan(user, interest_rate_type: "floating")
      loan.interest_rate_periods.build(
        start_date: Date.today,
        annual_interest_rate: 8.5
      )
      expect(loan).to be_valid
    end

    it "does not apply the floating-rate period check on update" do
      user = valid_user
      # Create a valid floating-rate loan with a period
      loan = build_loan(user, interest_rate_type: "floating")
      loan.interest_rate_periods.build(start_date: Date.today, annual_interest_rate: 8.5)
      loan.save!

      # Remove all periods and update — the on: :create validation should not fire
      loan.interest_rate_periods.destroy_all
      loan.institution_name = "Updated Bank"
      expect(loan).to be_valid
    end

    it "does not apply the floating-rate period check to fixed-rate loans" do
      user = valid_user
      loan = build_loan(user, interest_rate_type: "fixed")
      expect(loan).to be_valid
    end
  end

  # ---------------------------------------------------------------------------
  # 7. Presence validations
  # ---------------------------------------------------------------------------
  describe "presence validations" do
    it "is invalid without institution_name" do
      user = valid_user
      loan = build_loan(user, institution_name: "")
      expect(loan).not_to be_valid
      expect(loan.errors[:institution_name]).to be_present
    end

    it "is invalid without loan_identifier" do
      user = valid_user
      loan = build_loan(user, loan_identifier: "")
      expect(loan).not_to be_valid
      expect(loan.errors[:loan_identifier]).to be_present
    end
  end

  # ---------------------------------------------------------------------------
  # 8. INTEREST_RATE_TYPES constant
  # ---------------------------------------------------------------------------
  describe "INTEREST_RATE_TYPES" do
    it "contains exactly 'fixed' and 'floating'" do
      expect(Loan::INTEREST_RATE_TYPES).to eq(%w[fixed floating])
    end

    it "is frozen" do
      expect(Loan::INTEREST_RATE_TYPES).to be_frozen
    end
  end

  # ---------------------------------------------------------------------------
  # 9. for_user scope
  # ---------------------------------------------------------------------------
  describe ".for_user scope" do
    it "returns only loans belonging to the given user" do
      user_a = valid_user
      user_b = User.create!(identifier: "+14155559999", password: "securepass")

      create_loan(user_a)
      create_loan(user_b)

      result = Loan.for_user(user_a)
      expect(result.count).to eq(1)
      expect(result.first.user).to eq(user_a)
    end

    it "returns an empty relation when the user has no loans" do
      user = valid_user
      expect(Loan.for_user(user)).to be_empty
    end

    it "returns all loans for a user when they have multiple" do
      user = valid_user
      create_loan(user, loan_identifier: "LOAN-001")
      create_loan(user, loan_identifier: "LOAN-002")

      expect(Loan.for_user(user).count).to eq(2)
    end
  end

  # ---------------------------------------------------------------------------
  # 10. Associations
  # ---------------------------------------------------------------------------
  describe "associations" do
    it "belongs to a user" do
      user = valid_user
      loan = create_loan(user)
      expect(loan.user).to eq(user)
    end

    it "destroys associated interest_rate_periods when destroyed" do
      user = valid_user
      loan = build_loan(user, interest_rate_type: "floating")
      loan.interest_rate_periods.build(start_date: Date.today, annual_interest_rate: 8.5)
      loan.save!

      period_id = loan.interest_rate_periods.first.id
      loan.destroy

      expect(InterestRatePeriod.find_by(id: period_id)).to be_nil
    end
  end
end
