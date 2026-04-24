# frozen_string_literal: true

require "rails_helper"

RSpec.describe Savings::SavingsManager do
  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  def create_user(identifier = "+14155552671")
    User.create!(identifier: identifier, password: "securepass")
  end

  def valid_instrument_params(overrides = {})
    {
      institution_name:       "SBI",
      savings_identifier:     "FD-2024-001",
      savings_type:           "fd",
      principal_amount:       100_000_000,
      annual_interest_rate:   7.0,
      contribution_frequency: "one_time",
      start_date:             Date.new(2024, 1, 15),
      maturity_date:          Date.new(2026, 1, 15)
    }.merge(overrides)
  end

  def valid_rd_params(overrides = {})
    valid_instrument_params(
      savings_identifier:     "RD-2024-001",
      savings_type:           "rd",
      contribution_frequency: "monthly",
      recurring_amount:       500_000
    ).merge(overrides)
  end

  # ---------------------------------------------------------------------------
  # .create
  # ---------------------------------------------------------------------------

  describe ".create" do
    context "with valid one-time savings params" do
      it "creates and returns a savings instrument associated with the user" do
        user       = create_user
        instrument = described_class.create(user: user, params: valid_instrument_params)

        expect(instrument).to be_a(SavingsInstrument)
        expect(instrument).to be_persisted
        expect(instrument.user).to eq(user)
        expect(instrument.institution_name).to eq("SBI")
        expect(instrument.savings_identifier).to eq("FD-2024-001")
        expect(instrument.savings_type).to eq("fd")
        expect(instrument.principal_amount).to eq(100_000_000)
        expect(instrument.annual_interest_rate.to_f).to eq(7.0)
        expect(instrument.contribution_frequency).to eq("one_time")
      end
    end

    context "with valid recurring savings params" do
      it "creates and returns a recurring savings instrument" do
        user       = create_user("+14155550100")
        instrument = described_class.create(user: user, params: valid_rd_params)

        expect(instrument).to be_persisted
        expect(instrument.contribution_frequency).to eq("monthly")
        expect(instrument.recurring_amount).to eq(500_000)
      end
    end

    context "when principal_amount is zero" do
      it "raises ValidationError with details on principal_amount" do
        user = create_user("+14155550101")
        expect {
          described_class.create(user: user, params: valid_instrument_params(principal_amount: 0))
        }.to raise_error(Savings::SavingsManager::ValidationError) do |error|
          expect(error.details).to have_key(:principal_amount)
        end
      end
    end

    context "when principal_amount is negative" do
      it "raises ValidationError" do
        user = create_user("+14155550102")
        expect {
          described_class.create(user: user, params: valid_instrument_params(principal_amount: -1))
        }.to raise_error(Savings::SavingsManager::ValidationError)
      end
    end

    context "when annual_interest_rate is below 0" do
      it "raises ValidationError with details on annual_interest_rate" do
        user = create_user("+14155550103")
        expect {
          described_class.create(user: user, params: valid_instrument_params(annual_interest_rate: -0.1))
        }.to raise_error(Savings::SavingsManager::ValidationError) do |error|
          expect(error.details).to have_key(:annual_interest_rate)
        end
      end
    end

    context "when annual_interest_rate is above 100" do
      it "raises ValidationError with details on annual_interest_rate" do
        user = create_user("+14155550104")
        expect {
          described_class.create(user: user, params: valid_instrument_params(annual_interest_rate: 100.1))
        }.to raise_error(Savings::SavingsManager::ValidationError) do |error|
          expect(error.details).to have_key(:annual_interest_rate)
        end
      end
    end

    context "when contribution_frequency is not one_time and recurring_amount is absent" do
      it "raises ValidationError with details on recurring_amount" do
        user = create_user("+14155550105")
        expect {
          described_class.create(
            user:   user,
            params: valid_instrument_params(
              contribution_frequency: "monthly",
              recurring_amount:       nil
            )
          )
        }.to raise_error(Savings::SavingsManager::ValidationError) do |error|
          expect(error.details).to have_key(:recurring_amount)
        end
      end
    end

    context "when maturity_date is before start_date" do
      it "raises ValidationError with details on maturity_date" do
        user = create_user("+14155550106")
        expect {
          described_class.create(
            user:   user,
            params: valid_instrument_params(
              start_date:    Date.new(2026, 1, 15),
              maturity_date: Date.new(2024, 1, 15)
            )
          )
        }.to raise_error(Savings::SavingsManager::ValidationError) do |error|
          expect(error.details).to have_key(:maturity_date)
        end
      end
    end

    context "when maturity_date equals start_date" do
      it "raises ValidationError with details on maturity_date" do
        user = create_user("+14155550107")
        expect {
          described_class.create(
            user:   user,
            params: valid_instrument_params(
              start_date:    Date.new(2024, 1, 15),
              maturity_date: Date.new(2024, 1, 15)
            )
          )
        }.to raise_error(Savings::SavingsManager::ValidationError) do |error|
          expect(error.details).to have_key(:maturity_date)
        end
      end
    end

    context "ValidationError error class" do
      it "carries field details via attr_reader and is a StandardError" do
        user  = create_user("+14155550108")
        error = nil

        begin
          described_class.create(user: user, params: valid_instrument_params(principal_amount: 0))
        rescue Savings::SavingsManager::ValidationError => e
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
    context "when the user has no savings instruments" do
      it "returns an empty array" do
        user = create_user("+14155550200")
        expect(described_class.list(user: user)).to eq([])
      end
    end

    context "when the user has savings instruments" do
      it "returns one item per instrument" do
        user = create_user("+14155550201")
        described_class.create(user: user, params: valid_instrument_params(savings_identifier: "FD-001"))
        described_class.create(user: user, params: valid_instrument_params(savings_identifier: "FD-002"))

        result = described_class.list(user: user)

        expect(result.length).to eq(2)
        expect(result.map { |h| h[:savings_identifier] }).to contain_exactly("FD-001", "FD-002")
      end

      it "includes maturity_value in each item" do
        user = create_user("+14155550202")
        instrument = described_class.create(user: user, params: valid_instrument_params)

        result = described_class.list(user: user)
        item   = result.first

        expected_maturity_value = Savings::ValueCalculator.maturity_value(instrument)
        expect(item[:maturity_value]).to eq(expected_maturity_value)
      end

      it "includes all required list fields in each item" do
        user = create_user("+14155550203")
        described_class.create(user: user, params: valid_instrument_params)

        item = described_class.list(user: user).first

        expect(item).to include(
          :id,
          :institution_name,
          :savings_identifier,
          :savings_type,
          :principal_amount,
          :annual_interest_rate,
          :contribution_frequency,
          :start_date,
          :maturity_date,
          :maturity_value
        )
      end

      it "does not include instruments belonging to other users" do
        user_a = create_user("+14155550204")
        user_b = create_user("+14155550205")

        described_class.create(user: user_a, params: valid_instrument_params(savings_identifier: "A-001"))
        described_class.create(user: user_b, params: valid_instrument_params(savings_identifier: "B-001"))

        result_a = described_class.list(user: user_a)
        result_b = described_class.list(user: user_b)

        expect(result_a.map { |h| h[:savings_identifier] }).to eq(["A-001"])
        expect(result_b.map { |h| h[:savings_identifier] }).to eq(["B-001"])
      end
    end
  end

  # ---------------------------------------------------------------------------
  # .show
  # ---------------------------------------------------------------------------

  describe ".show" do
    context "when the instrument belongs to the user" do
      it "returns a full instrument detail hash" do
        user       = create_user("+14155550300")
        instrument = described_class.create(user: user, params: valid_instrument_params)

        result = described_class.show(user: user, instrument_id: instrument.id)

        expect(result).to include(
          id:                     instrument.id,
          institution_name:       "SBI",
          savings_identifier:     "FD-2024-001",
          savings_type:           "fd",
          principal_amount:       100_000_000,
          contribution_frequency: "one_time",
          start_date:             Date.new(2024, 1, 15),
          maturity_date:          Date.new(2026, 1, 15)
        )
      end

      it "includes maturity_value in the returned hash" do
        user       = create_user("+14155550301")
        instrument = described_class.create(user: user, params: valid_instrument_params)

        result = described_class.show(user: user, instrument_id: instrument.id)

        expected = Savings::ValueCalculator.maturity_value(instrument)
        expect(result[:maturity_value]).to eq(expected)
      end

      it "includes payment_schedule in the returned hash" do
        user       = create_user("+14155550302")
        instrument = described_class.create(user: user, params: valid_instrument_params)

        result = described_class.show(user: user, instrument_id: instrument.id)

        expect(result).to have_key(:payment_schedule)
        expect(result[:payment_schedule]).to be_an(Array)
      end

      it "includes notes in the returned hash" do
        user       = create_user("+14155550303")
        instrument = described_class.create(user: user, params: valid_instrument_params(notes: "My FD"))

        result = described_class.show(user: user, instrument_id: instrument.id)

        expect(result[:notes]).to eq("My FD")
      end

      it "returns a non-empty payment_schedule for a recurring instrument" do
        user       = create_user("+14155550304")
        instrument = described_class.create(user: user, params: valid_rd_params)

        result = described_class.show(user: user, instrument_id: instrument.id)

        expect(result[:payment_schedule]).not_to be_empty
        first_entry = result[:payment_schedule].first
        expect(first_entry).to include(:contribution_date, :contribution_amount, :running_total)
      end
    end

    context "when the instrument_id does not exist" do
      it "raises NotFoundError" do
        user = create_user("+14155550305")

        expect {
          described_class.show(user: user, instrument_id: 999_999)
        }.to raise_error(Savings::SavingsManager::NotFoundError)
      end
    end

    context "when the instrument belongs to a different user" do
      it "raises NotFoundError" do
        owner      = create_user("+14155550306")
        other      = create_user("+14155550307")
        instrument = described_class.create(user: owner, params: valid_instrument_params)

        expect {
          described_class.show(user: other, instrument_id: instrument.id)
        }.to raise_error(Savings::SavingsManager::NotFoundError)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # .update
  # ---------------------------------------------------------------------------

  describe ".update" do
    context "with valid params" do
      it "returns the updated instrument with new field values" do
        user       = create_user("+14155550400")
        instrument = described_class.create(user: user, params: valid_instrument_params)

        updated = described_class.update(
          user:          user,
          instrument_id: instrument.id,
          params:        { institution_name: "HDFC", principal_amount: 200_000_000 }
        )

        expect(updated).to be_a(SavingsInstrument)
        expect(updated.id).to eq(instrument.id)
        expect(updated.institution_name).to eq("HDFC")
        expect(updated.principal_amount).to eq(200_000_000)
      end

      it "persists the changes to the database" do
        user       = create_user("+14155550401")
        instrument = described_class.create(user: user, params: valid_instrument_params)

        described_class.update(
          user:          user,
          instrument_id: instrument.id,
          params:        { notes: "Updated note" }
        )

        expect(instrument.reload.notes).to eq("Updated note")
      end
    end

    context "with invalid params" do
      it "raises ValidationError when principal_amount is 0" do
        user       = create_user("+14155550402")
        instrument = described_class.create(user: user, params: valid_instrument_params)

        expect {
          described_class.update(
            user:          user,
            instrument_id: instrument.id,
            params:        { principal_amount: 0 }
          )
        }.to raise_error(Savings::SavingsManager::ValidationError) do |error|
          expect(error.details).to have_key(:principal_amount)
        end
      end

      it "does not persist changes when validation fails" do
        user               = create_user("+14155550403")
        instrument         = described_class.create(user: user, params: valid_instrument_params)
        original_principal = instrument.principal_amount

        begin
          described_class.update(
            user:          user,
            instrument_id: instrument.id,
            params:        { principal_amount: 0 }
          )
        rescue Savings::SavingsManager::ValidationError
          # expected
        end

        expect(instrument.reload.principal_amount).to eq(original_principal)
      end

      it "raises ValidationError when annual_interest_rate is above 100" do
        user       = create_user("+14155550404")
        instrument = described_class.create(user: user, params: valid_instrument_params)

        expect {
          described_class.update(
            user:          user,
            instrument_id: instrument.id,
            params:        { annual_interest_rate: 101 }
          )
        }.to raise_error(Savings::SavingsManager::ValidationError) do |error|
          expect(error.details).to have_key(:annual_interest_rate)
        end
      end
    end

    context "when instrument_id does not exist" do
      it "raises NotFoundError" do
        user = create_user("+14155550405")

        expect {
          described_class.update(user: user, instrument_id: 999_999, params: { institution_name: "X" })
        }.to raise_error(Savings::SavingsManager::NotFoundError)
      end
    end

    context "when instrument belongs to a different user" do
      it "raises NotFoundError" do
        owner      = create_user("+14155550406")
        other      = create_user("+14155550407")
        instrument = described_class.create(user: owner, params: valid_instrument_params)

        expect {
          described_class.update(user: other, instrument_id: instrument.id, params: { institution_name: "X" })
        }.to raise_error(Savings::SavingsManager::NotFoundError)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # .destroy
  # ---------------------------------------------------------------------------

  describe ".destroy" do
    context "when the instrument belongs to the user" do
      it "destroys the instrument" do
        user       = create_user("+14155550500")
        instrument = described_class.create(user: user, params: valid_instrument_params)

        described_class.destroy(user: user, instrument_id: instrument.id)

        expect(SavingsInstrument.find_by(id: instrument.id)).to be_nil
      end

      it "returns nil" do
        user       = create_user("+14155550501")
        instrument = described_class.create(user: user, params: valid_instrument_params)

        result = described_class.destroy(user: user, instrument_id: instrument.id)

        expect(result).to be_nil
      end
    end

    context "when instrument_id does not exist" do
      it "raises NotFoundError" do
        user = create_user("+14155550502")

        expect {
          described_class.destroy(user: user, instrument_id: 999_999)
        }.to raise_error(Savings::SavingsManager::NotFoundError)
      end
    end

    context "when instrument belongs to a different user" do
      it "raises NotFoundError" do
        owner      = create_user("+14155550503")
        other      = create_user("+14155550504")
        instrument = described_class.create(user: owner, params: valid_instrument_params)

        expect {
          described_class.destroy(user: other, instrument_id: instrument.id)
        }.to raise_error(Savings::SavingsManager::NotFoundError)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # .dashboard_summary
  # ---------------------------------------------------------------------------

  describe ".dashboard_summary" do
    context "when the user has no savings instruments" do
      it "returns zero totals and an empty items array" do
        user   = create_user("+14155550600")
        result = described_class.dashboard_summary(user)

        expect(result[:total_count]).to eq(0)
        expect(result[:total_principal]).to eq(0)
        expect(result[:items]).to eq([])
      end
    end

    context "when the user has savings instruments" do
      it "returns the correct total_count" do
        user = create_user("+14155550601")
        described_class.create(user: user, params: valid_instrument_params(savings_identifier: "FD-001"))
        described_class.create(user: user, params: valid_instrument_params(savings_identifier: "FD-002"))

        result = described_class.dashboard_summary(user)

        expect(result[:total_count]).to eq(2)
      end

      it "returns the correct total_principal" do
        user = create_user("+14155550602")
        described_class.create(user: user, params: valid_instrument_params(savings_identifier: "FD-001", principal_amount: 100_000_000))
        described_class.create(user: user, params: valid_instrument_params(savings_identifier: "FD-002", principal_amount: 200_000_000))

        result = described_class.dashboard_summary(user)

        expect(result[:total_principal]).to eq(300_000_000)
      end

      it "returns items with the required fields" do
        user = create_user("+14155550603")
        described_class.create(user: user, params: valid_instrument_params)

        result = described_class.dashboard_summary(user)
        item   = result[:items].first

        expect(item).to include(
          :id,
          :institution_name,
          :savings_identifier,
          :savings_type,
          :principal_amount,
          :maturity_date
        )
      end

      it "does not include instruments belonging to other users" do
        user_a = create_user("+14155550604")
        user_b = create_user("+14155550605")

        described_class.create(user: user_a, params: valid_instrument_params(savings_identifier: "A-001"))
        described_class.create(user: user_b, params: valid_instrument_params(savings_identifier: "B-001"))

        result_a = described_class.dashboard_summary(user_a)
        result_b = described_class.dashboard_summary(user_b)

        expect(result_a[:total_count]).to eq(1)
        expect(result_b[:total_count]).to eq(1)
        expect(result_a[:items].map { |i| i[:savings_identifier] }).to eq(["A-001"])
        expect(result_b[:items].map { |i| i[:savings_identifier] }).to eq(["B-001"])
      end
    end
  end
end
