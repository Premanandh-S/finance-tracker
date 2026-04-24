# frozen_string_literal: true

require "rails_helper"

RSpec.describe InterestRatePeriod, type: :model do
  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  def valid_user
    User.create!(identifier: "+14155552671", password: "securepass")
  end

  def valid_loan(user)
    user.loans.create!(
      institution_name: "HDFC Bank",
      loan_identifier: "HL-2024-001",
      outstanding_balance: 250_000_00,
      annual_interest_rate: 8.5,
      interest_rate_type: "fixed",
      monthly_payment: 25_000_00,
      payment_due_day: 5
    )
  end

  def valid_period_attrs(overrides = {})
    {
      start_date: Date.new(2024, 1, 1),
      annual_interest_rate: 8.5
    }.merge(overrides)
  end

  def build_period(loan, overrides = {})
    loan.interest_rate_periods.build(valid_period_attrs(overrides))
  end

  # ---------------------------------------------------------------------------
  # 1. Valid interest_rate_period
  # ---------------------------------------------------------------------------
  describe "valid interest_rate_period" do
    it "is valid with all required attributes" do
      loan = valid_loan(valid_user)
      period = build_period(loan)
      expect(period).to be_valid
    end
  end

  # ---------------------------------------------------------------------------
  # 2. start_date validations
  # ---------------------------------------------------------------------------
  describe "start_date" do
    it "is invalid when start_date is missing" do
      loan = valid_loan(valid_user)
      period = build_period(loan, start_date: nil)
      expect(period).not_to be_valid
      expect(period.errors[:start_date]).to be_present
    end
  end

  # ---------------------------------------------------------------------------
  # 3. annual_interest_rate validations
  # ---------------------------------------------------------------------------
  describe "annual_interest_rate" do
    it "is invalid when annual_interest_rate is below 0" do
      loan = valid_loan(valid_user)
      period = build_period(loan, annual_interest_rate: -0.1)
      expect(period).not_to be_valid
      expect(period.errors[:annual_interest_rate]).to be_present
    end

    it "is invalid when annual_interest_rate is above 100" do
      loan = valid_loan(valid_user)
      period = build_period(loan, annual_interest_rate: 100.1)
      expect(period).not_to be_valid
      expect(period.errors[:annual_interest_rate]).to be_present
    end

    it "is valid when annual_interest_rate is exactly 0" do
      loan = valid_loan(valid_user)
      period = build_period(loan, annual_interest_rate: 0)
      expect(period).to be_valid
    end

    it "is valid when annual_interest_rate is exactly 100" do
      loan = valid_loan(valid_user)
      period = build_period(loan, annual_interest_rate: 100)
      expect(period).to be_valid
    end
  end

  # ---------------------------------------------------------------------------
  # 4. end_date is optional
  # ---------------------------------------------------------------------------
  describe "end_date" do
    it "is valid when end_date is nil (open-ended period)" do
      loan = valid_loan(valid_user)
      period = build_period(loan, end_date: nil)
      expect(period).to be_valid
    end

    it "is valid when end_date is set to a date" do
      loan = valid_loan(valid_user)
      period = build_period(loan, end_date: Date.new(2024, 12, 31))
      expect(period).to be_valid
    end
  end

  # ---------------------------------------------------------------------------
  # 5. Associations
  # ---------------------------------------------------------------------------
  describe "associations" do
    it "belongs to a loan" do
      loan = valid_loan(valid_user)
      period = loan.interest_rate_periods.create!(valid_period_attrs)
      expect(period.loan).to eq(loan)
    end
  end
end
