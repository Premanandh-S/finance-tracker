# frozen_string_literal: true

require "rails_helper"

RSpec.describe Loans::PaymentCalculator do
  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  def valid_user
    User.create!(identifier: "+14155552671", password: "securepass")
  end

  # Builds a persisted fixed-rate loan with sensible defaults.
  # outstanding_balance: 1_000_000 (paise), rate: 12% p.a., monthly_payment: 100_000
  # => monthly interest = floor((1_000_000 * 12 / 100) / 12 + 0.5) = floor(10_000.5) = 10_000
  # => principal = 100_000 - 10_000 = 90_000
  def create_fixed_loan(user, overrides = {})
    attrs = {
      institution_name:    "Test Bank",
      loan_identifier:     "LOAN-001",
      outstanding_balance: 1_000_000,
      annual_interest_rate: 12.0,
      interest_rate_type:  "fixed",
      monthly_payment:     100_000,
      payment_due_day:     15
    }.merge(overrides)
    user.loans.create!(attrs)
  end

  # ---------------------------------------------------------------------------
  # 1. Non-empty schedule for a fixed-rate loan
  # ---------------------------------------------------------------------------
  describe ".amortisation_schedule" do
    context "with a standard fixed-rate loan" do
      it "produces a non-empty schedule" do
        user = valid_user
        loan = create_fixed_loan(user)
        schedule = described_class.amortisation_schedule(loan)
        expect(schedule).not_to be_empty
      end

      # -----------------------------------------------------------------------
      # 2. First period interest formula
      # -----------------------------------------------------------------------
      it "computes first period interest as floor((balance * rate / 100) / 12 + 0.5)" do
        user = valid_user
        loan = create_fixed_loan(user)
        schedule = described_class.amortisation_schedule(loan)

        balance  = loan.outstanding_balance.to_f
        rate     = loan.annual_interest_rate.to_f
        expected_interest = ((balance * rate / 100.0) / 12.0 + 0.5).floor

        expect(schedule.first[:interest]).to eq(expected_interest)
      end

      # -----------------------------------------------------------------------
      # 3. First period principal = monthly_payment - interest
      # -----------------------------------------------------------------------
      it "computes first period principal as monthly_payment minus interest" do
        user = valid_user
        loan = create_fixed_loan(user)
        schedule = described_class.amortisation_schedule(loan)

        first = schedule.first
        expect(first[:principal]).to eq(loan.monthly_payment - first[:interest])
      end

      # -----------------------------------------------------------------------
      # 4. First period remaining_balance = balance - principal
      # -----------------------------------------------------------------------
      it "computes first period remaining_balance as outstanding_balance minus principal" do
        user = valid_user
        loan = create_fixed_loan(user)
        schedule = described_class.amortisation_schedule(loan)

        first = schedule.first
        expect(first[:remaining_balance]).to eq(loan.outstanding_balance - first[:principal])
      end

      # -----------------------------------------------------------------------
      # 5. Final period has remaining_balance of 0
      # -----------------------------------------------------------------------
      it "has a remaining_balance of 0 in the final period" do
        user = valid_user
        loan = create_fixed_loan(user)
        schedule = described_class.amortisation_schedule(loan)

        expect(schedule.last[:remaining_balance]).to eq(0)
      end

      # -----------------------------------------------------------------------
      # 6. Sum of all principals equals initial outstanding_balance (within 1)
      # -----------------------------------------------------------------------
      it "sums all principal components to the initial outstanding_balance within tolerance of 1" do
        user = valid_user
        loan = create_fixed_loan(user)
        schedule = described_class.amortisation_schedule(loan)

        total_principal = schedule.sum { |entry| entry[:principal] }
        expect((total_principal - loan.outstanding_balance).abs).to be <= 1
      end

      # -----------------------------------------------------------------------
      # 7. Schedule entries have the expected keys
      # -----------------------------------------------------------------------
      it "returns entries with all required keys" do
        user = valid_user
        loan = create_fixed_loan(user)
        schedule = described_class.amortisation_schedule(loan)

        expected_keys = %i[period payment_date payment_amount principal interest remaining_balance]
        schedule.each do |entry|
          expect(entry.keys).to match_array(expected_keys)
        end
      end

      # -----------------------------------------------------------------------
      # 8. Period numbers are sequential starting from 1
      # -----------------------------------------------------------------------
      it "assigns sequential 1-based period numbers" do
        user = valid_user
        loan = create_fixed_loan(user)
        schedule = described_class.amortisation_schedule(loan)

        schedule.each_with_index do |entry, idx|
          expect(entry[:period]).to eq(idx + 1)
        end
      end

      # -----------------------------------------------------------------------
      # 9. Payment dates advance by one month each period
      # -----------------------------------------------------------------------
      it "advances payment_date by one month per period" do
        user = valid_user
        loan = create_fixed_loan(user)
        schedule = described_class.amortisation_schedule(loan)

        schedule.each_cons(2) do |prev, curr|
          expect(curr[:payment_date]).to eq(prev[:payment_date] >> 1)
        end
      end
    end

    # -------------------------------------------------------------------------
    # 10. NonConvergingLoanError when monthly_payment <= interest
    # -------------------------------------------------------------------------
    context "when monthly_payment is less than or equal to first period interest" do
      it "raises NonConvergingLoanError" do
        user = valid_user
        # balance: 10_000_000, rate: 24% => monthly interest = floor((10_000_000 * 24/100)/12 + 0.5)
        #   = floor(200_000.5) = 200_000
        # monthly_payment: 100_000 < 200_000 => non-converging
        loan = create_fixed_loan(user,
          outstanding_balance:  10_000_000,
          annual_interest_rate: 24.0,
          monthly_payment:      100_000
        )

        expect {
          described_class.amortisation_schedule(loan)
        }.to raise_error(Loans::PaymentCalculator::NonConvergingLoanError)
      end

      it "raises NonConvergingLoanError when monthly_payment exactly equals interest" do
        user = valid_user
        # balance: 1_200_000, rate: 12% => monthly interest = floor((1_200_000 * 12/100)/12 + 0.5)
        #   = floor(12_000.5) = 12_000
        # monthly_payment: 12_000 == 12_000 => non-converging
        loan = create_fixed_loan(user,
          outstanding_balance:  1_200_000,
          annual_interest_rate: 12.0,
          monthly_payment:      12_000
        )

        expect {
          described_class.amortisation_schedule(loan)
        }.to raise_error(Loans::PaymentCalculator::NonConvergingLoanError)
      end
    end

    # -------------------------------------------------------------------------
    # 11. Schedule capped at 600 periods
    # -------------------------------------------------------------------------
    context "when the loan would take more than 600 periods to pay off" do
      it "caps the schedule at 600 periods" do
        user = valid_user
        # balance: 1_000_000, rate: 1% p.a.
        # monthly interest = floor((1_000_000 * 1/100)/12 + 0.5) = floor(833.83...) = 834
        # monthly_payment: 835 — barely above interest, so it would take thousands of periods
        loan = create_fixed_loan(user,
          outstanding_balance:  1_000_000,
          annual_interest_rate: 1.0,
          monthly_payment:      835
        )

        schedule = described_class.amortisation_schedule(loan)
        expect(schedule.length).to eq(600)
      end
    end

    # -------------------------------------------------------------------------
    # 12. Final period payment_amount = remaining_balance + interest
    # -------------------------------------------------------------------------
    context "final period adjustment" do
      it "sets final payment_amount to the exact remaining balance plus interest" do
        user = valid_user
        # Use a small loan that pays off quickly so we can verify the final entry
        # balance: 100_000, rate: 12%, monthly_payment: 50_000
        # period 1: interest = floor((100_000 * 12/100)/12 + 0.5) = floor(1_000.5) = 1_000
        #           principal = 50_000 - 1_000 = 49_000
        #           remaining = 100_000 - 49_000 = 51_000
        # period 2: interest = floor((51_000 * 12/100)/12 + 0.5) = floor(510.5) = 510
        #           principal = 50_000 - 510 = 49_490
        #           remaining = 51_000 - 49_490 = 1_510 > 0
        # period 3: interest = floor((1_510 * 12/100)/12 + 0.5) = floor(15.6) = 15
        #           principal = 50_000 - 15 = 49_985 > 1_510 => final period
        #           payment_amount = 1_510 + 15 = 1_525, principal = 1_510, remaining = 0
        loan = create_fixed_loan(user,
          outstanding_balance:  100_000,
          annual_interest_rate: 12.0,
          monthly_payment:      50_000
        )

        schedule = described_class.amortisation_schedule(loan)
        last_entry = schedule.last

        expect(last_entry[:remaining_balance]).to eq(0)
        expect(last_entry[:payment_amount]).to eq(last_entry[:principal] + last_entry[:interest])
      end
    end
  end

  # ---------------------------------------------------------------------------
  # next_payment_date
  # ---------------------------------------------------------------------------
  describe ".next_payment_date" do
    it "returns the due date in the current month when today is before the due day" do
      user = valid_user
      loan = create_fixed_loan(user, payment_due_day: 20)

      # Freeze time to the 10th of a month (before due day 20)
      travel_to Date.new(2025, 7, 10) do
        result = described_class.next_payment_date(loan)
        expect(result).to eq(Date.new(2025, 7, 20))
      end
    end

    it "returns the due date in the next month when today is on the due day" do
      user = valid_user
      loan = create_fixed_loan(user, payment_due_day: 10)

      travel_to Date.new(2025, 7, 10) do
        result = described_class.next_payment_date(loan)
        expect(result).to eq(Date.new(2025, 8, 10))
      end
    end

    it "returns the due date in the next month when today is after the due day" do
      user = valid_user
      loan = create_fixed_loan(user, payment_due_day: 5)

      travel_to Date.new(2025, 7, 15) do
        result = described_class.next_payment_date(loan)
        expect(result).to eq(Date.new(2025, 8, 5))
      end
    end

    it "handles month-boundary correctly (December → January)" do
      user = valid_user
      loan = create_fixed_loan(user, payment_due_day: 15)

      travel_to Date.new(2025, 12, 20) do
        result = described_class.next_payment_date(loan)
        expect(result).to eq(Date.new(2026, 1, 15))
      end
    end
  end

  # ---------------------------------------------------------------------------
  # payoff_date
  # ---------------------------------------------------------------------------
  describe ".payoff_date" do
    it "returns the payment_date of the last schedule entry" do
      user = valid_user
      loan = create_fixed_loan(user)
      schedule = described_class.amortisation_schedule(loan)

      expect(described_class.payoff_date(loan)).to eq(schedule.last[:payment_date])
    end
  end

  # ---------------------------------------------------------------------------
  # Floating-rate amortisation
  # ---------------------------------------------------------------------------
  describe ".amortisation_schedule (floating-rate)" do
    # Builds a persisted floating-rate loan with two rate periods:
    #   Period A: 2025-01-01 → 2025-06-30  @ 12% p.a.
    #   Period B: 2025-07-01 → nil (open)  @ 18% p.a.
    #
    # outstanding_balance: 600_000, monthly_payment: 60_000
    # First payment date is forced to 2025-02-15 by freezing time to 2025-02-01.
    def create_floating_loan(user, overrides = {})
      loan = user.loans.build(
        {
          institution_name:     "Float Bank",
          loan_identifier:      "FL-001",
          outstanding_balance:  600_000,
          annual_interest_rate: 0.0,   # not used for floating; required by model
          interest_rate_type:   "floating",
          monthly_payment:      60_000,
          payment_due_day:      15
        }.merge(overrides)
      )
      loan.interest_rate_periods.build(
        start_date:          Date.new(2025, 1, 1),
        end_date:            Date.new(2025, 6, 30),
        annual_interest_rate: 12.0
      )
      loan.interest_rate_periods.build(
        start_date:          Date.new(2025, 7, 1),
        end_date:            nil,
        annual_interest_rate: 18.0
      )
      loan.save!
      loan
    end

    # -------------------------------------------------------------------------
    # 1. Correct rate applied per period based on date ranges
    # -------------------------------------------------------------------------
    it "uses the correct rate for each period based on date ranges" do
      user = valid_user

      # Freeze to 2025-02-01 so first payment_date = 2025-02-15 (in 12% window)
      travel_to Date.new(2025, 2, 1) do
        loan     = create_floating_loan(user)
        schedule = described_class.amortisation_schedule(loan)

        # Verify every entry uses the rate that covers its payment_date
        rate_periods = loan.interest_rate_periods.to_a

        schedule.each do |entry|
          pd = entry[:payment_date]

          covering = rate_periods.find do |rp|
            rp.start_date <= pd && (rp.end_date.nil? || rp.end_date >= pd)
          end
          expected_rate = if covering
                           covering.annual_interest_rate.to_f
                         else
                           rate_periods.max_by(&:start_date).annual_interest_rate.to_f
                         end

          balance_before = if entry[:period] == 1
                             loan.outstanding_balance.to_f
                           else
                             schedule[entry[:period] - 2][:remaining_balance].to_f
                           end

          expected_interest = ((balance_before * expected_rate / 100.0) / 12.0 + 0.5).floor
          expect(entry[:interest]).to eq(expected_interest),
            "Period #{entry[:period]} (#{pd}): expected interest #{expected_interest} " \
            "using rate #{expected_rate}%, got #{entry[:interest]}"
        end
      end
    end

    # -------------------------------------------------------------------------
    # 2. Falls back to most recent period's rate when payment_date is beyond
    #    all defined periods
    # -------------------------------------------------------------------------
    it "falls back to the most recent period's rate when payment_date is beyond all defined periods" do
      user = valid_user

      # Create a loan with a single closed period ending 2025-03-31.
      # Payments that fall after 2025-03-31 must use that period's rate.
      loan = user.loans.build(
        institution_name:     "Fallback Bank",
        loan_identifier:      "FB-001",
        outstanding_balance:  120_000,
        annual_interest_rate: 0.0,
        interest_rate_type:   "floating",
        monthly_payment:      15_000,
        payment_due_day:      1
      )
      loan.interest_rate_periods.build(
        start_date:           Date.new(2025, 1, 1),
        end_date:             Date.new(2025, 3, 31),
        annual_interest_rate: 9.0
      )
      loan.save!

      # Freeze to 2025-01-01 so first payment_date = 2025-02-01 (within period).
      # The loan takes ~9 months to pay off, so later payments fall outside the period.
      travel_to Date.new(2025, 1, 1) do
        schedule = described_class.amortisation_schedule(loan)

        beyond_entries = schedule.select { |e| e[:payment_date] > Date.new(2025, 3, 31) }
        expect(beyond_entries).not_to be_empty, "Expected some entries beyond the defined period"

        beyond_entries.each do |entry|
          pd             = entry[:payment_date]
          balance_before = if entry[:period] == 1
                             loan.outstanding_balance.to_f
                           else
                             schedule[entry[:period] - 2][:remaining_balance].to_f
                           end
          expected_interest = ((balance_before * 9.0 / 100.0) / 12.0 + 0.5).floor
          expect(entry[:interest]).to eq(expected_interest),
            "Period #{entry[:period]} (#{pd}): expected fallback interest #{expected_interest}, got #{entry[:interest]}"
        end
      end
    end

    # -------------------------------------------------------------------------
    # 3. Final period has remaining_balance of 0
    # -------------------------------------------------------------------------
    it "has a remaining_balance of 0 in the final period" do
      user = valid_user

      travel_to Date.new(2025, 2, 1) do
        loan     = create_floating_loan(user)
        schedule = described_class.amortisation_schedule(loan)

        expect(schedule.last[:remaining_balance]).to eq(0)
      end
    end

    # -------------------------------------------------------------------------
    # 4. Sum of principals equals initial outstanding_balance within tolerance 1
    # -------------------------------------------------------------------------
    it "sums all principal components to the initial outstanding_balance within tolerance of 1" do
      user = valid_user

      travel_to Date.new(2025, 2, 1) do
        loan     = create_floating_loan(user)
        schedule = described_class.amortisation_schedule(loan)

        total_principal = schedule.sum { |entry| entry[:principal] }
        expect((total_principal - loan.outstanding_balance).abs).to be <= 1
      end
    end
  end

  # ---------------------------------------------------------------------------
  # dashboard_summary
  # ---------------------------------------------------------------------------
  describe ".dashboard_summary" do
    context "when the user has loans" do
      it "returns total_count equal to the number of loans" do
        user = valid_user
        create_fixed_loan(user, loan_identifier: "LOAN-001", outstanding_balance: 500_000)
        create_fixed_loan(user, loan_identifier: "LOAN-002", outstanding_balance: 300_000)

        result = described_class.dashboard_summary(user)
        expect(result[:total_count]).to eq(2)
      end

      it "returns total_outstanding_balance equal to the sum of all outstanding balances" do
        user = valid_user
        create_fixed_loan(user, loan_identifier: "LOAN-001", outstanding_balance: 500_000)
        create_fixed_loan(user, loan_identifier: "LOAN-002", outstanding_balance: 300_000)

        result = described_class.dashboard_summary(user)
        expect(result[:total_outstanding_balance]).to eq(800_000)
      end

      it "returns each item with id, institution_name, outstanding_balance, and next_payment_date" do
        user = valid_user
        loan = create_fixed_loan(user, loan_identifier: "LOAN-001", outstanding_balance: 500_000)

        travel_to Date.new(2025, 7, 10) do
          result = described_class.dashboard_summary(user)
          item   = result[:items].first

          expect(item[:id]).to eq(loan.id)
          expect(item[:institution_name]).to eq(loan.institution_name)
          expect(item[:outstanding_balance]).to eq(loan.outstanding_balance)
          expect(item[:next_payment_date]).to eq(described_class.next_payment_date(loan))
        end
      end
    end

    context "when the user has no loans" do
      it "returns total_count: 0, total_outstanding_balance: 0, items: []" do
        user   = valid_user
        result = described_class.dashboard_summary(user)

        expect(result[:total_count]).to eq(0)
        expect(result[:total_outstanding_balance]).to eq(0)
        expect(result[:items]).to eq([])
      end
    end
  end
end
