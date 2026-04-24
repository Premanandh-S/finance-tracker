# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pensions::PensionManager do
  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  def create_user(identifier = "+14155552671")
    User.create!(identifier: identifier, password: "securepass")
  end

  def valid_instrument_params(overrides = {})
    {
      institution_name:   "EPFO",
      pension_identifier: "EPF-2024-001",
      pension_type:       "epf"
    }.merge(overrides)
  end

  def valid_contribution_params(overrides = {})
    {
      contribution_date: Date.new(2024, 6, 1),
      amount:            180_000,
      contributor_type:  "employee"
    }.merge(overrides)
  end

  # ---------------------------------------------------------------------------
  # .create
  # ---------------------------------------------------------------------------

  describe ".create" do
    context "with valid required params" do
      it "creates and returns a pension instrument associated with the user" do
        user       = create_user
        instrument = described_class.create(user: user, params: valid_instrument_params)

        expect(instrument).to be_a(PensionInstrument)
        expect(instrument).to be_persisted
        expect(instrument.user).to eq(user)
        expect(instrument.institution_name).to eq("EPFO")
        expect(instrument.pension_identifier).to eq("EPF-2024-001")
        expect(instrument.pension_type).to eq("epf")
      end

      it "creates with optional monthly_contribution_amount" do
        user       = create_user("+14155550001")
        instrument = described_class.create(
          user:   user,
          params: valid_instrument_params(monthly_contribution_amount: 180_000)
        )

        expect(instrument.monthly_contribution_amount).to eq(180_000)
      end
    end

    context "when monthly_contribution_amount is zero" do
      it "raises ValidationError with details on monthly_contribution_amount" do
        user = create_user("+14155550002")
        expect {
          described_class.create(
            user:   user,
            params: valid_instrument_params(monthly_contribution_amount: 0)
          )
        }.to raise_error(Pensions::PensionManager::ValidationError) do |error|
          expect(error.details).to have_key(:monthly_contribution_amount)
        end
      end
    end

    context "when maturity_date is before contribution_start_date" do
      it "raises ValidationError with details on maturity_date" do
        user = create_user("+14155550003")
        expect {
          described_class.create(
            user:   user,
            params: valid_instrument_params(
              contribution_start_date: Date.new(2025, 1, 1),
              maturity_date:           Date.new(2024, 1, 1)
            )
          )
        }.to raise_error(Pensions::PensionManager::ValidationError) do |error|
          expect(error.details).to have_key(:maturity_date)
        end
      end
    end

    context "ValidationError error class" do
      it "carries field details and is a StandardError" do
        user  = create_user("+14155550004")
        error = nil

        begin
          described_class.create(
            user:   user,
            params: valid_instrument_params(monthly_contribution_amount: 0)
          )
        rescue Pensions::PensionManager::ValidationError => e
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
    context "when the user has no pension instruments" do
      it "returns an empty array" do
        user = create_user("+14155550100")
        expect(described_class.list(user: user)).to eq([])
      end
    end

    context "when the user has pension instruments" do
      it "returns one item per instrument" do
        user = create_user("+14155550101")
        described_class.create(user: user, params: valid_instrument_params(pension_identifier: "EPF-001"))
        described_class.create(user: user, params: valid_instrument_params(pension_identifier: "NPS-001", pension_type: "nps"))

        result = described_class.list(user: user)

        expect(result.length).to eq(2)
        expect(result.map { |h| h[:pension_identifier] }).to contain_exactly("EPF-001", "NPS-001")
      end

      it "includes total_corpus in each item" do
        user       = create_user("+14155550102")
        instrument = described_class.create(user: user, params: valid_instrument_params)
        described_class.add_contribution(user: user, instrument_id: instrument.id, params: valid_contribution_params(amount: 100_000))
        described_class.add_contribution(user: user, instrument_id: instrument.id, params: valid_contribution_params(amount: 80_000, contribution_date: Date.new(2024, 7, 1)))

        result = described_class.list(user: user)

        expect(result.first[:total_corpus]).to eq(180_000)
      end

      it "includes all required list fields" do
        user = create_user("+14155550103")
        described_class.create(user: user, params: valid_instrument_params)

        item = described_class.list(user: user).first

        expect(item).to include(
          :id, :institution_name, :pension_identifier, :pension_type,
          :monthly_contribution_amount, :contribution_start_date, :maturity_date, :total_corpus
        )
      end

      it "does not include instruments belonging to other users" do
        user_a = create_user("+14155550104")
        user_b = create_user("+14155550105")

        described_class.create(user: user_a, params: valid_instrument_params(pension_identifier: "A-001"))
        described_class.create(user: user_b, params: valid_instrument_params(pension_identifier: "B-001"))

        expect(described_class.list(user: user_a).map { |h| h[:pension_identifier] }).to eq(["A-001"])
        expect(described_class.list(user: user_b).map { |h| h[:pension_identifier] }).to eq(["B-001"])
      end
    end
  end

  # ---------------------------------------------------------------------------
  # .show
  # ---------------------------------------------------------------------------

  describe ".show" do
    context "when the instrument belongs to the user" do
      it "returns a full instrument detail hash" do
        user       = create_user("+14155550200")
        instrument = described_class.create(user: user, params: valid_instrument_params)

        result = described_class.show(user: user, instrument_id: instrument.id)

        expect(result).to include(
          id:                 instrument.id,
          institution_name:   "EPFO",
          pension_identifier: "EPF-2024-001",
          pension_type:       "epf"
        )
      end

      it "includes total_corpus in the returned hash" do
        user       = create_user("+14155550201")
        instrument = described_class.create(user: user, params: valid_instrument_params)
        described_class.add_contribution(user: user, instrument_id: instrument.id, params: valid_contribution_params(amount: 180_000))

        result = described_class.show(user: user, instrument_id: instrument.id)

        expect(result[:total_corpus]).to eq(180_000)
      end

      it "includes contributions ordered by contribution_date descending" do
        user       = create_user("+14155550202")
        instrument = described_class.create(user: user, params: valid_instrument_params)
        described_class.add_contribution(user: user, instrument_id: instrument.id, params: valid_contribution_params(contribution_date: Date.new(2024, 5, 1), amount: 100_000))
        described_class.add_contribution(user: user, instrument_id: instrument.id, params: valid_contribution_params(contribution_date: Date.new(2024, 6, 1), amount: 80_000))

        result = described_class.show(user: user, instrument_id: instrument.id)

        dates = result[:contributions].map { |c| c[:contribution_date] }
        expect(dates).to eq(dates.sort.reverse)
      end

      it "includes all required contribution fields" do
        user       = create_user("+14155550203")
        instrument = described_class.create(user: user, params: valid_instrument_params)
        described_class.add_contribution(user: user, instrument_id: instrument.id, params: valid_contribution_params)

        contribution = described_class.show(user: user, instrument_id: instrument.id)[:contributions].first

        expect(contribution).to include(:id, :contribution_date, :amount, :contributor_type)
      end
    end

    context "when the instrument_id does not exist" do
      it "raises NotFoundError" do
        user = create_user("+14155550204")

        expect {
          described_class.show(user: user, instrument_id: 999_999)
        }.to raise_error(Pensions::PensionManager::NotFoundError)
      end
    end

    context "when the instrument belongs to a different user" do
      it "raises NotFoundError" do
        owner      = create_user("+14155550205")
        other      = create_user("+14155550206")
        instrument = described_class.create(user: owner, params: valid_instrument_params)

        expect {
          described_class.show(user: other, instrument_id: instrument.id)
        }.to raise_error(Pensions::PensionManager::NotFoundError)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # .update
  # ---------------------------------------------------------------------------

  describe ".update" do
    context "with valid params" do
      it "returns the updated instrument with new field values" do
        user       = create_user("+14155550300")
        instrument = described_class.create(user: user, params: valid_instrument_params)

        updated = described_class.update(
          user:          user,
          instrument_id: instrument.id,
          params:        { institution_name: "NPS Trust", pension_type: "nps" }
        )

        expect(updated.institution_name).to eq("NPS Trust")
        expect(updated.pension_type).to eq("nps")
      end
    end

    context "with invalid params" do
      it "raises ValidationError when monthly_contribution_amount is 0" do
        user       = create_user("+14155550301")
        instrument = described_class.create(user: user, params: valid_instrument_params)

        expect {
          described_class.update(
            user:          user,
            instrument_id: instrument.id,
            params:        { monthly_contribution_amount: 0 }
          )
        }.to raise_error(Pensions::PensionManager::ValidationError) do |error|
          expect(error.details).to have_key(:monthly_contribution_amount)
        end
      end
    end

    context "when instrument_id does not exist" do
      it "raises NotFoundError" do
        user = create_user("+14155550302")

        expect {
          described_class.update(user: user, instrument_id: 999_999, params: { institution_name: "X" })
        }.to raise_error(Pensions::PensionManager::NotFoundError)
      end
    end

    context "when instrument belongs to a different user" do
      it "raises NotFoundError" do
        owner      = create_user("+14155550303")
        other      = create_user("+14155550304")
        instrument = described_class.create(user: owner, params: valid_instrument_params)

        expect {
          described_class.update(user: other, instrument_id: instrument.id, params: { institution_name: "X" })
        }.to raise_error(Pensions::PensionManager::NotFoundError)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # .destroy
  # ---------------------------------------------------------------------------

  describe ".destroy" do
    context "when the instrument belongs to the user" do
      it "destroys the instrument" do
        user       = create_user("+14155550400")
        instrument = described_class.create(user: user, params: valid_instrument_params)

        described_class.destroy(user: user, instrument_id: instrument.id)

        expect(PensionInstrument.find_by(id: instrument.id)).to be_nil
      end

      it "returns nil" do
        user       = create_user("+14155550401")
        instrument = described_class.create(user: user, params: valid_instrument_params)

        expect(described_class.destroy(user: user, instrument_id: instrument.id)).to be_nil
      end

      it "cascades destruction to contributions" do
        user       = create_user("+14155550402")
        instrument = described_class.create(user: user, params: valid_instrument_params)
        described_class.add_contribution(user: user, instrument_id: instrument.id, params: valid_contribution_params)
        contribution_ids = instrument.pension_contributions.pluck(:id)

        described_class.destroy(user: user, instrument_id: instrument.id)

        contribution_ids.each do |cid|
          expect(PensionContribution.find_by(id: cid)).to be_nil
        end
      end
    end

    context "when instrument_id does not exist" do
      it "raises NotFoundError" do
        user = create_user("+14155550403")

        expect {
          described_class.destroy(user: user, instrument_id: 999_999)
        }.to raise_error(Pensions::PensionManager::NotFoundError)
      end
    end

    context "when instrument belongs to a different user" do
      it "raises NotFoundError" do
        owner      = create_user("+14155550404")
        other      = create_user("+14155550405")
        instrument = described_class.create(user: owner, params: valid_instrument_params)

        expect {
          described_class.destroy(user: other, instrument_id: instrument.id)
        }.to raise_error(Pensions::PensionManager::NotFoundError)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # .add_contribution
  # ---------------------------------------------------------------------------

  describe ".add_contribution" do
    context "with valid params" do
      it "creates a contribution and returns the updated instrument detail" do
        user       = create_user("+14155550500")
        instrument = described_class.create(user: user, params: valid_instrument_params)

        result = described_class.add_contribution(
          user:          user,
          instrument_id: instrument.id,
          params:        valid_contribution_params
        )

        expect(result[:contributions].length).to eq(1)
        expect(result[:contributions].first[:amount]).to eq(180_000)
        expect(result[:contributions].first[:contributor_type]).to eq("employee")
      end

      it "increases total_corpus by the contribution amount" do
        user       = create_user("+14155550501")
        instrument = described_class.create(user: user, params: valid_instrument_params)

        result = described_class.add_contribution(
          user:          user,
          instrument_id: instrument.id,
          params:        valid_contribution_params(amount: 250_000)
        )

        expect(result[:total_corpus]).to eq(250_000)
      end
    end

    context "when amount is zero" do
      it "raises ValidationError with details on amount" do
        user       = create_user("+14155550502")
        instrument = described_class.create(user: user, params: valid_instrument_params)

        expect {
          described_class.add_contribution(
            user:          user,
            instrument_id: instrument.id,
            params:        valid_contribution_params(amount: 0)
          )
        }.to raise_error(Pensions::PensionManager::ValidationError) do |error|
          expect(error.details).to have_key(:amount)
        end
      end
    end

    context "when instrument does not belong to the user" do
      it "raises NotFoundError" do
        owner      = create_user("+14155550503")
        other      = create_user("+14155550504")
        instrument = described_class.create(user: owner, params: valid_instrument_params)

        expect {
          described_class.add_contribution(
            user:          other,
            instrument_id: instrument.id,
            params:        valid_contribution_params
          )
        }.to raise_error(Pensions::PensionManager::NotFoundError)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # .update_contribution
  # ---------------------------------------------------------------------------

  describe ".update_contribution" do
    context "with valid params" do
      it "updates the contribution and returns the updated instrument detail" do
        user         = create_user("+14155550600")
        instrument   = described_class.create(user: user, params: valid_instrument_params)
        result       = described_class.add_contribution(user: user, instrument_id: instrument.id, params: valid_contribution_params(amount: 100_000))
        contribution = instrument.pension_contributions.first

        result = described_class.update_contribution(
          user:            user,
          instrument_id:   instrument.id,
          contribution_id: contribution.id,
          params:          { amount: 200_000 }
        )

        updated = result[:contributions].find { |c| c[:id] == contribution.id }
        expect(updated[:amount]).to eq(200_000)
        expect(result[:total_corpus]).to eq(200_000)
      end
    end

    context "when contribution does not belong to the instrument" do
      it "raises NotFoundError" do
        user       = create_user("+14155550601")
        instrument = described_class.create(user: user, params: valid_instrument_params)

        expect {
          described_class.update_contribution(
            user:            user,
            instrument_id:   instrument.id,
            contribution_id: 999_999,
            params:          { amount: 100_000 }
          )
        }.to raise_error(Pensions::PensionManager::NotFoundError)
      end
    end

    context "when instrument does not belong to the user" do
      it "raises NotFoundError" do
        owner      = create_user("+14155550602")
        other      = create_user("+14155550603")
        instrument = described_class.create(user: owner, params: valid_instrument_params)
        described_class.add_contribution(user: owner, instrument_id: instrument.id, params: valid_contribution_params)
        contribution = instrument.pension_contributions.first

        expect {
          described_class.update_contribution(
            user:            other,
            instrument_id:   instrument.id,
            contribution_id: contribution.id,
            params:          { amount: 100_000 }
          )
        }.to raise_error(Pensions::PensionManager::NotFoundError)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # .remove_contribution
  # ---------------------------------------------------------------------------

  describe ".remove_contribution" do
    context "when the contribution belongs to the instrument" do
      it "removes the contribution and returns the updated instrument detail" do
        user       = create_user("+14155550700")
        instrument = described_class.create(user: user, params: valid_instrument_params)
        described_class.add_contribution(user: user, instrument_id: instrument.id, params: valid_contribution_params(amount: 100_000))
        described_class.add_contribution(user: user, instrument_id: instrument.id, params: valid_contribution_params(amount: 80_000, contribution_date: Date.new(2024, 7, 1)))
        contribution_to_remove = instrument.pension_contributions.order(:contribution_date).first

        result = described_class.remove_contribution(
          user:            user,
          instrument_id:   instrument.id,
          contribution_id: contribution_to_remove.id
        )

        expect(result[:contributions].map { |c| c[:id] }).not_to include(contribution_to_remove.id)
        expect(result[:total_corpus]).to eq(80_000)
      end

      it "destroys the contribution record" do
        user       = create_user("+14155550701")
        instrument = described_class.create(user: user, params: valid_instrument_params)
        described_class.add_contribution(user: user, instrument_id: instrument.id, params: valid_contribution_params)
        contribution = instrument.pension_contributions.first

        described_class.remove_contribution(user: user, instrument_id: instrument.id, contribution_id: contribution.id)

        expect(PensionContribution.find_by(id: contribution.id)).to be_nil
      end
    end

    context "when contribution_id does not belong to the instrument" do
      it "raises NotFoundError" do
        user       = create_user("+14155550702")
        instrument = described_class.create(user: user, params: valid_instrument_params)

        expect {
          described_class.remove_contribution(user: user, instrument_id: instrument.id, contribution_id: 999_999)
        }.to raise_error(Pensions::PensionManager::NotFoundError)
      end
    end

    context "when instrument does not belong to the user" do
      it "raises NotFoundError" do
        owner      = create_user("+14155550703")
        other      = create_user("+14155550704")
        instrument = described_class.create(user: owner, params: valid_instrument_params)
        described_class.add_contribution(user: owner, instrument_id: instrument.id, params: valid_contribution_params)
        contribution = instrument.pension_contributions.first

        expect {
          described_class.remove_contribution(user: other, instrument_id: instrument.id, contribution_id: contribution.id)
        }.to raise_error(Pensions::PensionManager::NotFoundError)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # .dashboard_summary
  # ---------------------------------------------------------------------------

  describe ".dashboard_summary" do
    context "when the user has no pension instruments" do
      it "returns zero count, zero corpus, and empty items" do
        user   = create_user("+14155550800")
        result = described_class.dashboard_summary(user)

        expect(result[:total_count]).to eq(0)
        expect(result[:total_corpus]).to eq(0)
        expect(result[:items]).to eq([])
      end
    end

    context "when the user has pension instruments" do
      it "returns the correct total_count" do
        user = create_user("+14155550801")
        described_class.create(user: user, params: valid_instrument_params(pension_identifier: "EPF-001"))
        described_class.create(user: user, params: valid_instrument_params(pension_identifier: "NPS-001", pension_type: "nps"))

        expect(described_class.dashboard_summary(user)[:total_count]).to eq(2)
      end

      it "returns the correct aggregate total_corpus" do
        user       = create_user("+14155550802")
        instrument = described_class.create(user: user, params: valid_instrument_params)
        described_class.add_contribution(user: user, instrument_id: instrument.id, params: valid_contribution_params(amount: 100_000))
        described_class.add_contribution(user: user, instrument_id: instrument.id, params: valid_contribution_params(amount: 80_000, contribution_date: Date.new(2024, 7, 1)))

        expect(described_class.dashboard_summary(user)[:total_corpus]).to eq(180_000)
      end

      it "returns items with the required fields" do
        user = create_user("+14155550803")
        described_class.create(user: user, params: valid_instrument_params)

        item = described_class.dashboard_summary(user)[:items].first

        expect(item).to include(:id, :institution_name, :pension_identifier, :pension_type, :total_corpus)
      end

      it "does not include instruments belonging to other users" do
        user_a = create_user("+14155550804")
        user_b = create_user("+14155550805")

        described_class.create(user: user_a, params: valid_instrument_params(pension_identifier: "A-001"))
        described_class.create(user: user_b, params: valid_instrument_params(pension_identifier: "B-001"))

        expect(described_class.dashboard_summary(user_a)[:total_count]).to eq(1)
        expect(described_class.dashboard_summary(user_b)[:total_count]).to eq(1)
      end
    end
  end
end
