# frozen_string_literal: true

require "rails_helper"

RSpec.describe Loans::LoanManager do
  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  def create_user(identifier = "+14155552671")
    User.create!(identifier: identifier, password: "securepass")
  end

  def valid_loan_params(overrides = {})
    {
      institution_name:    "HDFC Bank",
      loan_identifier:     "HL-2024-001",
      outstanding_balance: 250_000_00,
      annual_interest_rate: 8.5,
      interest_rate_type:  "fixed",
      monthly_payment:     25_000_00,
      payment_due_day:     5
    }.merge(overrides)
  end

  def valid_floating_params(overrides = {})
    valid_loan_params(
      interest_rate_type:   "floating",
      interest_rate_periods: [
        { start_date: Date.today, annual_interest_rate: 8.5 }
      ]
    ).merge(overrides)
  end

  # ---------------------------------------------------------------------------
  # .create
  # ---------------------------------------------------------------------------

  describe ".create" do
    context "with valid fixed-rate params" do
      it "creates and returns a loan associated with the user" do
        user = create_user
        loan = described_class.create(user: user, params: valid_loan_params)

        expect(loan).to be_a(Loan)
        expect(loan).to be_persisted
        expect(loan.user).to eq(user)
        expect(loan.institution_name).to eq("HDFC Bank")
        expect(loan.loan_identifier).to eq("HL-2024-001")
        expect(loan.outstanding_balance).to eq(250_000_00)
        expect(loan.annual_interest_rate).to eq(8.5)
        expect(loan.interest_rate_type).to eq("fixed")
        expect(loan.monthly_payment).to eq(25_000_00)
        expect(loan.payment_due_day).to eq(5)
      end
    end

    context "when outstanding_balance is zero" do
      it "raises ValidationError" do
        user = create_user
        expect {
          described_class.create(user: user, params: valid_loan_params(outstanding_balance: 0))
        }.to raise_error(Loans::LoanManager::ValidationError) do |error|
          expect(error.details).to have_key("outstanding_balance")
        end
      end
    end

    context "when outstanding_balance is negative" do
      it "raises ValidationError" do
        user = create_user
        expect {
          described_class.create(user: user, params: valid_loan_params(outstanding_balance: -1))
        }.to raise_error(Loans::LoanManager::ValidationError) do |error|
          expect(error.details).to have_key("outstanding_balance")
        end
      end
    end

    context "when annual_interest_rate is below 0" do
      it "raises ValidationError" do
        user = create_user
        expect {
          described_class.create(user: user, params: valid_loan_params(annual_interest_rate: -0.1))
        }.to raise_error(Loans::LoanManager::ValidationError) do |error|
          expect(error.details).to have_key("annual_interest_rate")
        end
      end
    end

    context "when annual_interest_rate is above 100" do
      it "raises ValidationError" do
        user = create_user
        expect {
          described_class.create(user: user, params: valid_loan_params(annual_interest_rate: 100.1))
        }.to raise_error(Loans::LoanManager::ValidationError) do |error|
          expect(error.details).to have_key("annual_interest_rate")
        end
      end
    end

    context "when payment_due_day is 0" do
      it "raises ValidationError" do
        user = create_user
        expect {
          described_class.create(user: user, params: valid_loan_params(payment_due_day: 0))
        }.to raise_error(Loans::LoanManager::ValidationError) do |error|
          expect(error.details).to have_key("payment_due_day")
        end
      end
    end

    context "when payment_due_day is 29" do
      it "raises ValidationError" do
        user = create_user
        expect {
          described_class.create(user: user, params: valid_loan_params(payment_due_day: 29))
        }.to raise_error(Loans::LoanManager::ValidationError) do |error|
          expect(error.details).to have_key("payment_due_day")
        end
      end
    end

    context "when interest_rate_type is floating and no interest_rate_periods are provided" do
      it "raises ValidationError with details on interest_rate_periods" do
        user = create_user
        expect {
          described_class.create(
            user: user,
            params: valid_loan_params(interest_rate_type: "floating")
          )
        }.to raise_error(Loans::LoanManager::ValidationError) do |error|
          expect(error.details).to have_key("interest_rate_periods")
        end
      end
    end

    context "when interest_rate_type is floating and interest_rate_periods are provided" do
      it "creates the loan and persists the nested rate periods" do
        user = create_user
        params = valid_floating_params(
          interest_rate_periods: [
            { start_date: Date.today, annual_interest_rate: 8.5 },
            { start_date: Date.today >> 6, annual_interest_rate: 9.0 }
          ]
        )

        loan = described_class.create(user: user, params: params)

        expect(loan).to be_persisted
        expect(loan.interest_rate_type).to eq("floating")
        expect(loan.interest_rate_periods.count).to eq(2)
        expect(loan.interest_rate_periods.map(&:annual_interest_rate).map(&:to_f)).to contain_exactly(8.5, 9.0)
      end
    end

    context "ValidationError error class" do
      it "carries field details via attr_reader" do
        user = create_user
        error = nil

        begin
          described_class.create(user: user, params: valid_loan_params(outstanding_balance: 0))
        rescue Loans::LoanManager::ValidationError => e
          error = e
        end

        expect(error).not_to be_nil
        expect(error).to be_a(StandardError)
        expect(error.details).to be_a(Hash)
        expect(error.details).not_to be_empty
      end
    end
  end

  # ---------------------------------------------------------------------------
  # .list
  # ---------------------------------------------------------------------------

  describe ".list" do
    context "when the user has no loans" do
      it "returns an empty array" do
        user = create_user("+14155550001")
        expect(described_class.list(user: user)).to eq([])
      end
    end

    context "when the user has loans" do
      it "returns one item per loan" do
        user = create_user("+14155550002")
        described_class.create(user: user, params: valid_loan_params(loan_identifier: "L-001"))
        described_class.create(user: user, params: valid_loan_params(loan_identifier: "L-002"))

        result = described_class.list(user: user)

        expect(result.length).to eq(2)
        expect(result.map { |h| h[:loan_identifier] }).to contain_exactly("L-001", "L-002")
      end

      it "includes next_payment_date and payoff_date in each item" do
        freeze_time do
          user = create_user("+14155550003")
          loan = described_class.create(user: user, params: valid_loan_params)

          result = described_class.list(user: user)
          item   = result.first

          expected_next   = Loans::PaymentCalculator.next_payment_date(loan)
          expected_payoff = Loans::PaymentCalculator.payoff_date(loan)

          expect(item[:next_payment_date]).to eq(expected_next)
          expect(item[:payoff_date]).to eq(expected_payoff)
        end
      end

      it "includes all required loan fields in each item" do
        user = create_user("+14155550004")
        described_class.create(user: user, params: valid_loan_params)

        item = described_class.list(user: user).first

        expect(item).to include(
          :id,
          :institution_name,
          :loan_identifier,
          :outstanding_balance,
          :interest_rate_type,
          :annual_interest_rate,
          :monthly_payment,
          :next_payment_date,
          :payoff_date
        )
      end

      it "does not include loans belonging to other users" do
        user_a = create_user("+14155550005")
        user_b = create_user("+14155550006")

        described_class.create(user: user_a, params: valid_loan_params(loan_identifier: "A-001"))
        described_class.create(user: user_b, params: valid_loan_params(loan_identifier: "B-001"))

        result_a = described_class.list(user: user_a)
        result_b = described_class.list(user: user_b)

        expect(result_a.map { |h| h[:loan_identifier] }).to eq(["A-001"])
        expect(result_b.map { |h| h[:loan_identifier] }).to eq(["B-001"])
      end
    end
  end

  # ---------------------------------------------------------------------------
  # .show
  # ---------------------------------------------------------------------------

  describe ".show" do
    context "when the loan belongs to the user" do
      it "returns a full loan detail hash" do
        freeze_time do
          user = create_user("+14155550010")
          loan = described_class.create(user: user, params: valid_loan_params)

          result = described_class.show(user: user, loan_id: loan.id)

          expect(result).to include(
            id:                   loan.id,
            institution_name:     "HDFC Bank",
            loan_identifier:      "HL-2024-001",
            outstanding_balance:  250_000_00,
            interest_rate_type:   "fixed",
            annual_interest_rate: loan.annual_interest_rate,
            monthly_payment:      25_000_00,
            payment_due_day:      5,
            next_payment_date:    Loans::PaymentCalculator.next_payment_date(loan),
            payoff_date:          Loans::PaymentCalculator.payoff_date(loan)
          )
        end
      end

      it "includes amortisation_schedule in the returned hash" do
        user = create_user("+14155550011")
        loan = described_class.create(user: user, params: valid_loan_params)

        result = described_class.show(user: user, loan_id: loan.id)

        expect(result).to have_key(:amortisation_schedule)
        expect(result[:amortisation_schedule]).to be_an(Array)
        expect(result[:amortisation_schedule]).not_to be_empty

        first_entry = result[:amortisation_schedule].first
        expect(first_entry).to include(:period, :payment_date, :payment_amount, :principal, :interest, :remaining_balance)
      end

      it "includes interest_rate_periods in the returned hash" do
        user = create_user("+14155550012")
        loan = described_class.create(user: user, params: valid_floating_params)

        result = described_class.show(user: user, loan_id: loan.id)

        expect(result).to have_key(:interest_rate_periods)
        expect(result[:interest_rate_periods]).to be_an(Array)
        expect(result[:interest_rate_periods].first).to include(:id, :start_date, :end_date, :annual_interest_rate)
      end
    end

    context "when the loan_id does not exist" do
      it "raises NotFoundError" do
        user = create_user("+14155550013")

        expect {
          described_class.show(user: user, loan_id: 999_999)
        }.to raise_error(Loans::LoanManager::NotFoundError)
      end
    end

    context "when the loan belongs to a different user" do
      it "raises NotFoundError" do
        owner = create_user("+14155550014")
        other = create_user("+14155550015")
        loan  = described_class.create(user: owner, params: valid_loan_params)

        expect {
          described_class.show(user: other, loan_id: loan.id)
        }.to raise_error(Loans::LoanManager::NotFoundError)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # .destroy
  # ---------------------------------------------------------------------------

  describe ".destroy" do
    context "when the loan belongs to the user" do
      it "destroys the loan" do
        user = create_user("+14155550030")
        loan = described_class.create(user: user, params: valid_loan_params)

        described_class.destroy(user: user, loan_id: loan.id)

        expect(Loan.find_by(id: loan.id)).to be_nil
      end

      it "destroys associated interest_rate_periods" do
        user = create_user("+14155550031")
        loan = described_class.create(user: user, params: valid_floating_params(
          interest_rate_periods: [
            { start_date: Date.today, annual_interest_rate: 8.5 },
            { start_date: Date.today >> 6, annual_interest_rate: 9.0 }
          ]
        ))
        period_ids = loan.interest_rate_periods.pluck(:id)
        expect(period_ids).not_to be_empty

        described_class.destroy(user: user, loan_id: loan.id)

        expect(InterestRatePeriod.where(id: period_ids)).to be_empty
      end

      it "returns nil" do
        user = create_user("+14155550032")
        loan = described_class.create(user: user, params: valid_loan_params)

        result = described_class.destroy(user: user, loan_id: loan.id)

        expect(result).to be_nil
      end
    end

    context "when loan_id does not exist" do
      it "raises NotFoundError" do
        user = create_user("+14155550033")

        expect {
          described_class.destroy(user: user, loan_id: 999_999)
        }.to raise_error(Loans::LoanManager::NotFoundError)
      end
    end

    context "when loan belongs to a different user" do
      it "raises NotFoundError" do
        owner = create_user("+14155550034")
        other = create_user("+14155550035")
        loan  = described_class.create(user: owner, params: valid_loan_params)

        expect {
          described_class.destroy(user: other, loan_id: loan.id)
        }.to raise_error(Loans::LoanManager::NotFoundError)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # .update
  # ---------------------------------------------------------------------------

  describe ".update" do
    context "with valid params" do
      it "returns the updated loan with new field values" do
        user = create_user("+14155550020")
        loan = described_class.create(user: user, params: valid_loan_params)

        updated = described_class.update(
          user:    user,
          loan_id: loan.id,
          params:  { institution_name: "SBI", outstanding_balance: 100_000_00 }
        )

        expect(updated).to be_a(Loan)
        expect(updated.id).to eq(loan.id)
        expect(updated.institution_name).to eq("SBI")
        expect(updated.outstanding_balance).to eq(100_000_00)
      end

      it "persists the changes to the database" do
        user = create_user("+14155550021")
        loan = described_class.create(user: user, params: valid_loan_params)

        described_class.update(
          user:    user,
          loan_id: loan.id,
          params:  { monthly_payment: 30_000_00 }
        )

        expect(loan.reload.monthly_payment).to eq(30_000_00)
      end
    end

    context "with invalid params" do
      it "raises ValidationError when outstanding_balance is 0" do
        user = create_user("+14155550022")
        loan = described_class.create(user: user, params: valid_loan_params)

        expect {
          described_class.update(
            user:    user,
            loan_id: loan.id,
            params:  { outstanding_balance: 0 }
          )
        }.to raise_error(Loans::LoanManager::ValidationError) do |error|
          expect(error.details).to have_key("outstanding_balance")
        end
      end

      it "does not persist changes when validation fails" do
        user = create_user("+14155550023")
        loan = described_class.create(user: user, params: valid_loan_params)
        original_balance = loan.outstanding_balance

        begin
          described_class.update(
            user:    user,
            loan_id: loan.id,
            params:  { outstanding_balance: 0 }
          )
        rescue Loans::LoanManager::ValidationError
          # expected
        end

        expect(loan.reload.outstanding_balance).to eq(original_balance)
      end
    end

    context "when loan_id does not exist" do
      it "raises NotFoundError" do
        user = create_user("+14155550024")

        expect {
          described_class.update(user: user, loan_id: 999_999, params: { institution_name: "X" })
        }.to raise_error(Loans::LoanManager::NotFoundError)
      end
    end

    context "when loan belongs to a different user" do
      it "raises NotFoundError" do
        owner = create_user("+14155550025")
        other = create_user("+14155550026")
        loan  = described_class.create(user: owner, params: valid_loan_params)

        expect {
          described_class.update(user: other, loan_id: loan.id, params: { institution_name: "X" })
        }.to raise_error(Loans::LoanManager::NotFoundError)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # .add_or_update_rate_period
  # ---------------------------------------------------------------------------

  describe ".add_or_update_rate_period" do
    def create_floating_loan(user, overrides = {})
      described_class.create(
        user: user,
        params: valid_floating_params(overrides)
      )
    end

    context "when creating a new rate period for a floating-rate loan" do
      it "creates a new rate period and returns the updated loan detail hash" do
        user = create_user("+14155550040")
        loan = create_floating_loan(user)
        initial_period_count = loan.interest_rate_periods.count

        result = described_class.add_or_update_rate_period(
          user:    user,
          loan_id: loan.id,
          params:  { start_date: Date.today >> 6, annual_interest_rate: 9.5 }
        )

        expect(result).to be_a(Hash)
        expect(result[:interest_rate_periods].length).to eq(initial_period_count + 1)
        new_period = result[:interest_rate_periods].find { |p| p[:annual_interest_rate].to_f == 9.5 }
        expect(new_period).not_to be_nil
      end
    end

    context "when updating an existing rate period" do
      it "updates the rate period when id is provided and returns the updated loan detail hash" do
        user = create_user("+14155550041")
        loan = create_floating_loan(user)
        existing_period = loan.interest_rate_periods.first

        result = described_class.add_or_update_rate_period(
          user:    user,
          loan_id: loan.id,
          params:  { id: existing_period.id, annual_interest_rate: 11.0 }
        )

        expect(result).to be_a(Hash)
        updated = result[:interest_rate_periods].find { |p| p[:id] == existing_period.id }
        expect(updated[:annual_interest_rate].to_f).to eq(11.0)
        # Count should remain the same — no new period was created
        expect(result[:interest_rate_periods].length).to eq(loan.interest_rate_periods.count)
      end
    end

    context "return value shape" do
      it "returns the updated loan detail hash with a recalculated amortisation_schedule" do
        user = create_user("+14155550042")
        loan = create_floating_loan(user)

        result = described_class.add_or_update_rate_period(
          user:    user,
          loan_id: loan.id,
          params:  { start_date: Date.today >> 3, annual_interest_rate: 10.0 }
        )

        expect(result).to include(
          :id,
          :institution_name,
          :loan_identifier,
          :outstanding_balance,
          :interest_rate_type,
          :annual_interest_rate,
          :monthly_payment,
          :payment_due_day,
          :next_payment_date,
          :payoff_date,
          :interest_rate_periods,
          :amortisation_schedule
        )
        expect(result[:amortisation_schedule]).to be_an(Array)
        expect(result[:amortisation_schedule]).not_to be_empty
        first_entry = result[:amortisation_schedule].first
        expect(first_entry).to include(:period, :payment_date, :payment_amount, :principal, :interest, :remaining_balance)
      end
    end

    context "when the loan is fixed-rate" do
      it "raises ValidationError with 'invalid_operation' message and descriptive details" do
        user = create_user("+14155550043")
        loan = described_class.create(user: user, params: valid_loan_params)

        expect {
          described_class.add_or_update_rate_period(
            user:    user,
            loan_id: loan.id,
            params:  { start_date: Date.today, annual_interest_rate: 9.0 }
          )
        }.to raise_error(Loans::LoanManager::ValidationError) do |error|
          expect(error.message).to eq("invalid_operation")
          expect(error.details).to eq({ "base" => ["Cannot add interest rate periods to a fixed-rate loan"] })
        end
      end
    end

    context "when loan_id does not exist" do
      it "raises NotFoundError" do
        user = create_user("+14155550044")

        expect {
          described_class.add_or_update_rate_period(
            user:    user,
            loan_id: 999_999,
            params:  { start_date: Date.today, annual_interest_rate: 9.0 }
          )
        }.to raise_error(Loans::LoanManager::NotFoundError)
      end
    end

    context "when the loan belongs to a different user" do
      it "raises NotFoundError" do
        owner = create_user("+14155550045")
        other = create_user("+14155550046")
        loan  = create_floating_loan(owner)

        expect {
          described_class.add_or_update_rate_period(
            user:    other,
            loan_id: loan.id,
            params:  { start_date: Date.today, annual_interest_rate: 9.0 }
          )
        }.to raise_error(Loans::LoanManager::NotFoundError)
      end
    end
  end
end
