# frozen_string_literal: true

require "rails_helper"

RSpec.describe Insurance::InsuranceManager do
  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  def create_user(identifier = "+14155552671")
    User.create!(identifier: identifier, password: "securepass")
  end

  def valid_policy_params(overrides = {})
    {
      institution_name:  "LIC",
      policy_number:     "POL-2024-001",
      policy_type:       "term",
      sum_assured:       1_000_000_000,
      premium_amount:    1_500_000,
      premium_frequency: "annually",
      renewal_date:      Date.current + 1.year
    }.merge(overrides)
  end

  # ---------------------------------------------------------------------------
  # .create
  # ---------------------------------------------------------------------------

  describe ".create" do
    context "with valid params and no insured_members" do
      it "creates and returns an insurance policy associated with the user" do
        user   = create_user
        policy = described_class.create(user: user, params: valid_policy_params)

        expect(policy).to be_a(InsurancePolicy)
        expect(policy).to be_persisted
        expect(policy.user).to eq(user)
        expect(policy.institution_name).to eq("LIC")
        expect(policy.policy_number).to eq("POL-2024-001")
        expect(policy.policy_type).to eq("term")
        expect(policy.sum_assured).to eq(1_000_000_000)
        expect(policy.premium_amount).to eq(1_500_000)
        expect(policy.premium_frequency).to eq("annually")
      end

      it "creates a policy with no insured members" do
        user   = create_user("+14155550001")
        policy = described_class.create(user: user, params: valid_policy_params)

        expect(policy.insured_members).to be_empty
      end
    end

    context "with valid params and nested insured_members" do
      it "creates the policy and its insured members" do
        user = create_user("+14155550002")
        params = valid_policy_params.merge(
          insured_members: [
            { name: "Alice", member_identifier: "MEM-A" },
            { name: "Bob" }
          ]
        )

        policy = described_class.create(user: user, params: params)

        expect(policy).to be_persisted
        expect(policy.insured_members.count).to eq(2)
        expect(policy.insured_members.map(&:name)).to contain_exactly("Alice", "Bob")
      end
    end

    context "when sum_assured is zero" do
      it "raises ValidationError with details on sum_assured" do
        user = create_user("+14155550003")
        expect {
          described_class.create(user: user, params: valid_policy_params(sum_assured: 0))
        }.to raise_error(Insurance::InsuranceManager::ValidationError) do |error|
          expect(error.details).to have_key(:sum_assured)
        end
      end
    end

    context "when premium_amount is zero" do
      it "raises ValidationError with details on premium_amount" do
        user = create_user("+14155550005")
        expect {
          described_class.create(user: user, params: valid_policy_params(premium_amount: 0))
        }.to raise_error(Insurance::InsuranceManager::ValidationError) do |error|
          expect(error.details).to have_key(:premium_amount)
        end
      end
    end

    context "when renewal_date is in the past" do
      it "raises ValidationError with details on renewal_date" do
        freeze_time do
          user = create_user("+14155550006")
          expect {
            described_class.create(
              user:   user,
              params: valid_policy_params(renewal_date: Date.current - 1.day)
            )
          }.to raise_error(Insurance::InsuranceManager::ValidationError) do |error|
            expect(error.details).to have_key(:renewal_date)
          end
        end
      end
    end

    context "when renewal_date is today" do
      it "raises ValidationError (must be strictly in the future)" do
        freeze_time do
          user = create_user("+14155550007")
          expect {
            described_class.create(
              user:   user,
              params: valid_policy_params(renewal_date: Date.current)
            )
          }.to raise_error(Insurance::InsuranceManager::ValidationError)
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # .list
  # ---------------------------------------------------------------------------

  describe ".list" do
    context "when the user has no insurance policies" do
      it "returns an empty array" do
        user = create_user("+14155550100")
        expect(described_class.list(user: user)).to eq([])
      end
    end

    context "when the user has insurance policies" do
      it "returns one item per policy" do
        user = create_user("+14155550101")
        described_class.create(user: user, params: valid_policy_params(policy_number: "POL-001"))
        described_class.create(user: user, params: valid_policy_params(policy_number: "POL-002"))

        result = described_class.list(user: user)

        expect(result.length).to eq(2)
        expect(result.map { |h| h[:policy_number] }).to contain_exactly("POL-001", "POL-002")
      end

      it "includes all required list fields in each item" do
        user = create_user("+14155550102")
        described_class.create(user: user, params: valid_policy_params)

        item = described_class.list(user: user).first

        expect(item).to include(
          :id, :institution_name, :policy_number, :policy_type,
          :sum_assured, :premium_amount, :premium_frequency, :renewal_date
        )
      end

      it "does not include policies belonging to other users" do
        user_a = create_user("+14155550103")
        user_b = create_user("+14155550104")

        described_class.create(user: user_a, params: valid_policy_params(policy_number: "A-001"))
        described_class.create(user: user_b, params: valid_policy_params(policy_number: "B-001"))

        expect(described_class.list(user: user_a).map { |h| h[:policy_number] }).to eq(["A-001"])
        expect(described_class.list(user: user_b).map { |h| h[:policy_number] }).to eq(["B-001"])
      end
    end
  end

  # ---------------------------------------------------------------------------
  # .show
  # ---------------------------------------------------------------------------

  describe ".show" do
    context "when the policy belongs to the user" do
      it "returns a full policy detail hash" do
        user   = create_user("+14155550200")
        policy = described_class.create(user: user, params: valid_policy_params)

        result = described_class.show(user: user, policy_id: policy.id)

        expect(result).to include(
          id: policy.id, institution_name: "LIC", policy_number: "POL-2024-001",
          policy_type: "term", sum_assured: 1_000_000_000
        )
      end

      it "includes insured_members array in the returned hash" do
        user = create_user("+14155550202")
        policy = described_class.create(
          user:   user,
          params: valid_policy_params.merge(
            insured_members: [{ name: "Alice", member_identifier: "MEM-A" }]
          )
        )

        result = described_class.show(user: user, policy_id: policy.id)

        expect(result[:insured_members]).to be_an(Array)
        expect(result[:insured_members].length).to eq(1)
        expect(result[:insured_members].first[:name]).to eq("Alice")
      end

      it "returns an empty insured_members array when policy has no members" do
        user   = create_user("+14155550203")
        policy = described_class.create(user: user, params: valid_policy_params)

        result = described_class.show(user: user, policy_id: policy.id)

        expect(result[:insured_members]).to eq([])
      end
    end

    context "when the policy_id does not exist" do
      it "raises NotFoundError" do
        user = create_user("+14155550204")

        expect {
          described_class.show(user: user, policy_id: 999_999)
        }.to raise_error(Insurance::InsuranceManager::NotFoundError)
      end
    end

    context "when the policy belongs to a different user" do
      it "raises NotFoundError" do
        owner  = create_user("+14155550205")
        other  = create_user("+14155550206")
        policy = described_class.create(user: owner, params: valid_policy_params)

        expect {
          described_class.show(user: other, policy_id: policy.id)
        }.to raise_error(Insurance::InsuranceManager::NotFoundError)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # .update
  # ---------------------------------------------------------------------------

  describe ".update" do
    context "with valid params" do
      it "returns the updated policy with new field values" do
        user   = create_user("+14155550300")
        policy = described_class.create(user: user, params: valid_policy_params)

        updated = described_class.update(
          user:      user,
          policy_id: policy.id,
          params:    { institution_name: "HDFC Life", sum_assured: 2_000_000_000 }
        )

        expect(updated.institution_name).to eq("HDFC Life")
        expect(updated.sum_assured).to eq(2_000_000_000)
      end
    end

    context "with invalid params" do
      it "raises ValidationError when sum_assured is 0" do
        user   = create_user("+14155550302")
        policy = described_class.create(user: user, params: valid_policy_params)

        expect {
          described_class.update(user: user, policy_id: policy.id, params: { sum_assured: 0 })
        }.to raise_error(Insurance::InsuranceManager::ValidationError) do |error|
          expect(error.details).to have_key(:sum_assured)
        end
      end

      it "raises ValidationError when renewal_date is in the past" do
        freeze_time do
          user   = create_user("+14155550304")
          policy = described_class.create(user: user, params: valid_policy_params)

          expect {
            described_class.update(
              user:      user,
              policy_id: policy.id,
              params:    { renewal_date: Date.current - 1.day }
            )
          }.to raise_error(Insurance::InsuranceManager::ValidationError) do |error|
            expect(error.details).to have_key(:renewal_date)
          end
        end
      end
    end

    context "when policy_id does not exist" do
      it "raises NotFoundError" do
        user = create_user("+14155550306")

        expect {
          described_class.update(user: user, policy_id: 999_999, params: { institution_name: "X" })
        }.to raise_error(Insurance::InsuranceManager::NotFoundError)
      end
    end

    context "when policy belongs to a different user" do
      it "raises NotFoundError" do
        owner  = create_user("+14155550307")
        other  = create_user("+14155550308")
        policy = described_class.create(user: owner, params: valid_policy_params)

        expect {
          described_class.update(user: other, policy_id: policy.id, params: { institution_name: "X" })
        }.to raise_error(Insurance::InsuranceManager::NotFoundError)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # .destroy
  # ---------------------------------------------------------------------------

  describe ".destroy" do
    context "when the policy belongs to the user" do
      it "destroys the policy" do
        user   = create_user("+14155550400")
        policy = described_class.create(user: user, params: valid_policy_params)

        described_class.destroy(user: user, policy_id: policy.id)

        expect(InsurancePolicy.find_by(id: policy.id)).to be_nil
      end

      it "returns nil" do
        user   = create_user("+14155550401")
        policy = described_class.create(user: user, params: valid_policy_params)

        expect(described_class.destroy(user: user, policy_id: policy.id)).to be_nil
      end

      it "cascades destruction to insured members" do
        user = create_user("+14155550402")
        policy = described_class.create(
          user:   user,
          params: valid_policy_params.merge(
            insured_members: [{ name: "Alice" }, { name: "Bob" }]
          )
        )
        member_ids = policy.insured_members.pluck(:id)

        described_class.destroy(user: user, policy_id: policy.id)

        member_ids.each do |mid|
          expect(InsuredMember.find_by(id: mid)).to be_nil
        end
      end
    end

    context "when policy_id does not exist" do
      it "raises NotFoundError" do
        user = create_user("+14155550403")

        expect {
          described_class.destroy(user: user, policy_id: 999_999)
        }.to raise_error(Insurance::InsuranceManager::NotFoundError)
      end
    end

    context "when policy belongs to a different user" do
      it "raises NotFoundError" do
        owner  = create_user("+14155550404")
        other  = create_user("+14155550405")
        policy = described_class.create(user: owner, params: valid_policy_params)

        expect {
          described_class.destroy(user: other, policy_id: policy.id)
        }.to raise_error(Insurance::InsuranceManager::NotFoundError)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # .add_or_update_member
  # ---------------------------------------------------------------------------

  describe ".add_or_update_member" do
    context "adding a new member (no :id in params)" do
      it "creates a new insured member on the policy" do
        user   = create_user("+14155550500")
        policy = described_class.create(user: user, params: valid_policy_params)

        result = described_class.add_or_update_member(
          user:      user,
          policy_id: policy.id,
          params:    { name: "Alice", member_identifier: "MEM-A" }
        )

        expect(result[:insured_members].length).to eq(1)
        expect(result[:insured_members].first[:name]).to eq("Alice")
      end

      it "raises ValidationError when member name is blank" do
        user   = create_user("+14155550502")
        policy = described_class.create(user: user, params: valid_policy_params)

        expect {
          described_class.add_or_update_member(
            user:      user,
            policy_id: policy.id,
            params:    { name: "" }
          )
        }.to raise_error(Insurance::InsuranceManager::ValidationError) do |error|
          expect(error.details).to have_key(:name)
        end
      end
    end

    context "updating an existing member (:id present in params)" do
      it "updates the existing member and returns the updated policy detail" do
        user = create_user("+14155550503")
        policy = described_class.create(
          user:   user,
          params: valid_policy_params.merge(
            insured_members: [{ name: "Alice", member_identifier: "MEM-A" }]
          )
        )
        member = policy.insured_members.first

        result = described_class.add_or_update_member(
          user:      user,
          policy_id: policy.id,
          params:    { id: member.id, name: "Alice Updated", member_identifier: "MEM-A-NEW" }
        )

        updated_member = result[:insured_members].find { |m| m[:id] == member.id }
        expect(updated_member[:name]).to eq("Alice Updated")
        expect(updated_member[:member_identifier]).to eq("MEM-A-NEW")
      end

      it "raises NotFoundError when the member_id does not belong to the policy" do
        user   = create_user("+14155550504")
        policy = described_class.create(user: user, params: valid_policy_params)

        expect {
          described_class.add_or_update_member(
            user:      user,
            policy_id: policy.id,
            params:    { id: 999_999, name: "Ghost" }
          )
        }.to raise_error(Insurance::InsuranceManager::NotFoundError)
      end
    end

    context "when the policy does not belong to the user" do
      it "raises NotFoundError" do
        owner  = create_user("+14155550505")
        other  = create_user("+14155550506")
        policy = described_class.create(user: owner, params: valid_policy_params)

        expect {
          described_class.add_or_update_member(
            user:      other,
            policy_id: policy.id,
            params:    { name: "Intruder" }
          )
        }.to raise_error(Insurance::InsuranceManager::NotFoundError)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # .remove_member
  # ---------------------------------------------------------------------------

  describe ".remove_member" do
    context "when the member belongs to the policy" do
      it "removes the member and returns the updated policy detail" do
        user = create_user("+14155550600")
        policy = described_class.create(
          user:   user,
          params: valid_policy_params.merge(
            insured_members: [{ name: "Alice" }, { name: "Bob" }]
          )
        )
        member_to_remove = policy.insured_members.find_by(name: "Alice")

        result = described_class.remove_member(
          user:      user,
          policy_id: policy.id,
          member_id: member_to_remove.id
        )

        expect(result[:insured_members].map { |m| m[:name] }).not_to include("Alice")
        expect(result[:insured_members].map { |m| m[:name] }).to include("Bob")
      end

      it "destroys the member record" do
        user = create_user("+14155550601")
        policy = described_class.create(
          user:   user,
          params: valid_policy_params.merge(insured_members: [{ name: "Alice" }])
        )
        member = policy.insured_members.first

        described_class.remove_member(user: user, policy_id: policy.id, member_id: member.id)

        expect(InsuredMember.find_by(id: member.id)).to be_nil
      end
    end

    context "when the member_id does not belong to the policy" do
      it "raises NotFoundError" do
        user   = create_user("+14155550603")
        policy = described_class.create(user: user, params: valid_policy_params)

        expect {
          described_class.remove_member(user: user, policy_id: policy.id, member_id: 999_999)
        }.to raise_error(Insurance::InsuranceManager::NotFoundError)
      end
    end

    context "when the policy does not belong to the user" do
      it "raises NotFoundError" do
        owner  = create_user("+14155550604")
        other  = create_user("+14155550605")
        policy = described_class.create(
          user:   owner,
          params: valid_policy_params.merge(insured_members: [{ name: "Alice" }])
        )
        member = policy.insured_members.first

        expect {
          described_class.remove_member(user: other, policy_id: policy.id, member_id: member.id)
        }.to raise_error(Insurance::InsuranceManager::NotFoundError)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # .dashboard_summary
  # ---------------------------------------------------------------------------

  describe ".dashboard_summary" do
    context "when the user has no insurance policies" do
      it "returns zero count and an empty items array" do
        user   = create_user("+14155550700")
        result = described_class.dashboard_summary(user)

        expect(result[:total_count]).to eq(0)
        expect(result[:items]).to eq([])
      end
    end

    context "when the user has insurance policies" do
      it "returns the correct total_count" do
        user = create_user("+14155550701")
        described_class.create(user: user, params: valid_policy_params(policy_number: "POL-001"))
        described_class.create(user: user, params: valid_policy_params(policy_number: "POL-002"))

        expect(described_class.dashboard_summary(user)[:total_count]).to eq(2)
      end

      it "returns items with the required fields" do
        user = create_user("+14155550702")
        described_class.create(user: user, params: valid_policy_params)

        item = described_class.dashboard_summary(user)[:items].first

        expect(item).to include(:id, :institution_name, :policy_number, :policy_type, :sum_assured, :renewal_date)
      end

      it "does not include policies belonging to other users" do
        user_a = create_user("+14155550704")
        user_b = create_user("+14155550705")

        described_class.create(user: user_a, params: valid_policy_params(policy_number: "A-001"))
        described_class.create(user: user_b, params: valid_policy_params(policy_number: "B-001"))

        expect(described_class.dashboard_summary(user_a)[:total_count]).to eq(1)
        expect(described_class.dashboard_summary(user_b)[:total_count]).to eq(1)
      end
    end
  end
end
