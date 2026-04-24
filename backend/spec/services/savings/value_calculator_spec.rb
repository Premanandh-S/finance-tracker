# frozen_string_literal: true

require "rails_helper"

RSpec.describe Savings::ValueCalculator do
  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  def valid_user
    User.create!(identifier: "+14155550001", password: "securepass")
  end

  # Builds a persisted one-time FD instrument with sensible defaults.
  def create_fd(user, overrides = {})
    attrs = {
      institution_name:      "SBI",
      savings_identifier:    "FD-001",
      savings_type:          "fd",
      principal_amount:      100_000_000,
      annual_interest_rate:  7.0,
      contribution_frequency: "one_time",
      start_date:            Date.new(2024, 1, 15),
      maturity_date:         Date.new(2026, 1, 15)
    }.merge(overrides)
    user.savings_instruments.create!(attrs)
  end

  # Builds a persisted monthly RD instrument.
  def create_monthly_rd(user, overrides = {})
    attrs = {
      institution_name:      "HDFC",
      savings_identifier:    "RD-001",
      savings_type:          "rd",
      principal_amount:      500_000,
      annual_interest_rate:  6.5,
      contribution_frequency: "monthly",
      recurring_amount:      500_000,
      start_date:            Date.new(2024, 1, 15),
      maturity_date:         Date.new(2024, 4, 15)
    }.merge(overrides)
    user.savings_instruments.create!(attrs)
  end

  # ---------------------------------------------------------------------------
  # maturity_value
  # ---------------------------------------------------------------------------
  describe ".maturity_value" do
    context "with a one-time FD with known principal, rate, and tenure" do
      it "returns the correct compound interest result" do
        user       = valid_user
        instrument = create_fd(user)

        # tenure_years = (2026-01-15 - 2024-01-15).to_f / 365.25
        # = 731.0 / 365.25 ≈ 1.99932...
        # raw = 100_000_000 * (1 + 7/100/4)^(4 * 1.99932...)
        # = 100_000_000 * (1.0175)^7.99726...
        tenure_years = (instrument.maturity_date - instrument.start_date).to_f / 365.25
        freq         = 4
        rate         = 7.0
        principal    = 100_000_000
        raw          = principal * ((1 + rate / 100.0 / freq) ** (freq * tenure_years))
        expected     = (raw + 0.5).floor

        result = described_class.maturity_value(instrument)
        expect(result).to eq(expected)
      end
    end

    context "when no maturity_date is present" do
      it "returns the principal_amount unchanged" do
        user       = valid_user
        instrument = create_fd(user, maturity_date: nil)

        expect(described_class.maturity_value(instrument)).to eq(instrument.principal_amount)
      end
    end

    context "return type" do
      it "returns an Integer, not a Float" do
        user       = valid_user
        instrument = create_fd(user)

        result = described_class.maturity_value(instrument)
        expect(result).to be_a(Integer)
      end

      it "returns an Integer when no maturity_date is present" do
        user       = valid_user
        instrument = create_fd(user, maturity_date: nil)

        result = described_class.maturity_value(instrument)
        expect(result).to be_a(Integer)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # payment_schedule
  # ---------------------------------------------------------------------------
  describe ".payment_schedule" do
    context "with a monthly RD over 3 months" do
      it "returns the correct number of entries" do
        user       = valid_user
        # start: 2024-01-15, maturity: 2024-04-15 → entries on Jan 15, Feb 15, Mar 15, Apr 15
        instrument = create_monthly_rd(user,
          start_date:   Date.new(2024, 1, 15),
          maturity_date: Date.new(2024, 4, 15)
        )

        schedule = described_class.payment_schedule(instrument)
        expect(schedule.length).to eq(4)
      end

      it "spaces entries exactly 1 month apart" do
        user       = valid_user
        instrument = create_monthly_rd(user,
          start_date:   Date.new(2024, 1, 15),
          maturity_date: Date.new(2024, 4, 15)
        )

        schedule = described_class.payment_schedule(instrument)
        schedule.each_cons(2) do |prev, curr|
          expect(curr[:contribution_date]).to eq(prev[:contribution_date] >> 1)
        end
      end

      it "accumulates running_totals correctly" do
        user       = valid_user
        instrument = create_monthly_rd(user,
          start_date:    Date.new(2024, 1, 15),
          maturity_date: Date.new(2024, 4, 15),
          recurring_amount: 500_000
        )

        schedule = described_class.payment_schedule(instrument)
        schedule.each_with_index do |entry, idx|
          expect(entry[:running_total]).to eq(500_000 * (idx + 1))
        end
      end

      it "sets contribution_amount to recurring_amount on every entry" do
        user       = valid_user
        instrument = create_monthly_rd(user,
          start_date:    Date.new(2024, 1, 15),
          maturity_date: Date.new(2024, 4, 15),
          recurring_amount: 500_000
        )

        schedule = described_class.payment_schedule(instrument)
        schedule.each do |entry|
          expect(entry[:contribution_amount]).to eq(500_000)
        end
      end
    end

    context "with a quarterly savings instrument" do
      it "spaces entries exactly 3 months apart" do
        user = valid_user
        instrument = user.savings_instruments.create!(
          institution_name:      "ICICI",
          savings_identifier:    "QRD-001",
          savings_type:          "rd",
          principal_amount:      1_000_000,
          annual_interest_rate:  6.0,
          contribution_frequency: "quarterly",
          recurring_amount:      1_000_000,
          start_date:            Date.new(2024, 1, 1),
          maturity_date:         Date.new(2025, 1, 1)
        )

        schedule = described_class.payment_schedule(instrument)
        expect(schedule).not_to be_empty
        schedule.each_cons(2) do |prev, curr|
          expect(curr[:contribution_date]).to eq(prev[:contribution_date] >> 3)
        end
      end
    end

    context "with an annually recurring savings instrument" do
      it "spaces entries exactly 12 months apart" do
        user = valid_user
        instrument = user.savings_instruments.create!(
          institution_name:      "Axis",
          savings_identifier:    "ARD-001",
          savings_type:          "rd",
          principal_amount:      2_000_000,
          annual_interest_rate:  7.0,
          contribution_frequency: "annually",
          recurring_amount:      2_000_000,
          start_date:            Date.new(2020, 1, 1),
          maturity_date:         Date.new(2025, 1, 1)
        )

        schedule = described_class.payment_schedule(instrument)
        expect(schedule).not_to be_empty
        schedule.each_cons(2) do |prev, curr|
          expect(curr[:contribution_date]).to eq(prev[:contribution_date] >> 12)
        end
      end
    end

    context "when no maturity_date is present" do
      it "returns an empty array" do
        user       = valid_user
        instrument = create_monthly_rd(user, maturity_date: nil)

        expect(described_class.payment_schedule(instrument)).to eq([])
      end
    end

    context "when contribution_frequency is one_time" do
      it "returns an empty array" do
        user       = valid_user
        instrument = create_fd(user)

        expect(described_class.payment_schedule(instrument)).to eq([])
      end
    end

    context "schedule cap" do
      it "caps the schedule at 600 entries for a very long tenure" do
        user = valid_user
        # Monthly contributions over 100 years → far more than 600 entries
        instrument = user.savings_instruments.create!(
          institution_name:      "LongBank",
          savings_identifier:    "LONG-001",
          savings_type:          "rd",
          principal_amount:      100_000,
          annual_interest_rate:  5.0,
          contribution_frequency: "monthly",
          recurring_amount:      100_000,
          start_date:            Date.new(2000, 1, 1),
          maturity_date:         Date.new(2100, 1, 1)
        )

        schedule = described_class.payment_schedule(instrument)
        expect(schedule.length).to eq(600)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # next_contribution_date
  # ---------------------------------------------------------------------------
  describe ".next_contribution_date" do
    context "when as_of day is before the start_date day-of-month" do
      it "returns a date in the same month as as_of" do
        user       = valid_user
        # start_date day = 20
        instrument = create_monthly_rd(user, start_date: Date.new(2024, 1, 20))

        # as_of day (10) < due_day (20) → same month
        travel_to Date.new(2025, 7, 10) do
          result = described_class.next_contribution_date(instrument)
          expect(result).to eq(Date.new(2025, 7, 20))
        end
      end
    end

    context "when as_of day equals the start_date day-of-month" do
      it "returns a date in the next month" do
        user       = valid_user
        # start_date day = 10
        instrument = create_monthly_rd(user, start_date: Date.new(2024, 1, 10))

        # as_of day (10) >= due_day (10) → next month
        travel_to Date.new(2025, 7, 10) do
          result = described_class.next_contribution_date(instrument)
          expect(result).to eq(Date.new(2025, 8, 10))
        end
      end
    end

    context "when as_of day is after the start_date day-of-month" do
      it "returns a date in the next month" do
        user       = valid_user
        # start_date day = 5
        instrument = create_monthly_rd(user, start_date: Date.new(2024, 1, 5))

        # as_of day (15) > due_day (5) → next month
        travel_to Date.new(2025, 7, 15) do
          result = described_class.next_contribution_date(instrument)
          expect(result).to eq(Date.new(2025, 8, 5))
        end
      end
    end

    context "month boundary" do
      it "handles December → January correctly" do
        user       = valid_user
        instrument = create_monthly_rd(user, start_date: Date.new(2024, 1, 15))

        travel_to Date.new(2025, 12, 20) do
          result = described_class.next_contribution_date(instrument)
          expect(result).to eq(Date.new(2026, 1, 15))
        end
      end
    end
  end
end
