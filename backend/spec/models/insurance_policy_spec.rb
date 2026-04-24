# frozen_string_literal: true

require "rails_helper"

RSpec.describe InsurancePolicy, type: :model do
  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  def valid_user
    User.create!(identifier: "+14155552671", password: "securepass")
  end

  def valid_attrs(overrides = {})
    {
      institution_name: "LIC",
      policy_number: "POL-2024-001",
      policy_type: "term",
      sum_assured: 1_000_000_000,
      premium_amount: 1_500_000,
      premium_frequency: "annually",
      renewal_date: Date.today + 365
    }.merge(overrides)
  end

  def build_policy(user, overrides = {})
    user.insurance_policies.build(valid_attrs(overrides))
  end

  def create_policy(user, overrides = {})
    user.insurance_policies.create!(valid_attrs(overrides))
  end

  # ---------------------------------------------------------------------------
  # 1. Valid policy
  # ---------------------------------------------------------------------------
  describe "valid insurance policy" do
    it "is valid with all required attributes" do
      user = valid_user
      policy = build_policy(user)
      expect(policy).to be_valid
    end

    it "is valid with an optional policy_start_date" do
      user = valid_user
      policy = build_policy(user, policy_start_date: Date.today - 365)
      expect(policy).to be_valid
    end

    it "is valid with optional notes" do
      user = valid_user
      policy = build_policy(user, notes: "Some notes about the policy")
      expect(policy).to be_valid
    end
  end

  # ---------------------------------------------------------------------------
  # 2. Presence validations
  # ---------------------------------------------------------------------------
  describe "presence validations" do
    it "is invalid without institution_name" do
      user = valid_user
      policy = build_policy(user, institution_name: "")
      expect(policy).not_to be_valid
      expect(policy.errors[:institution_name]).to be_present
    end

    it "is invalid without policy_number" do
      user = valid_user
      policy = build_policy(user, policy_number: "")
      expect(policy).not_to be_valid
      expect(policy.errors[:policy_number]).to be_present
    end

    it "is invalid without renewal_date" do
      user = valid_user
      policy = build_policy(user, renewal_date: nil)
      expect(policy).not_to be_valid
      expect(policy.errors[:renewal_date]).to be_present
    end
  end

  # ---------------------------------------------------------------------------
  # 3. sum_assured validations
  # ---------------------------------------------------------------------------
  describe "sum_assured" do
    it "is invalid when sum_assured is zero" do
      user = valid_user
      policy = build_policy(user, sum_assured: 0)
      expect(policy).not_to be_valid
      expect(policy.errors[:sum_assured]).to be_present
    end

    it "is invalid when sum_assured is negative" do
      user = valid_user
      policy = build_policy(user, sum_assured: -1)
      expect(policy).not_to be_valid
      expect(policy.errors[:sum_assured]).to be_present
    end

    it "is invalid when sum_assured is a decimal" do
      user = valid_user
      policy = build_policy(user, sum_assured: 100.5)
      expect(policy).not_to be_valid
      expect(policy.errors[:sum_assured]).to be_present
    end

    it "is valid when sum_assured is a positive integer" do
      user = valid_user
      policy = build_policy(user, sum_assured: 1)
      expect(policy).to be_valid
    end
  end

  # ---------------------------------------------------------------------------
  # 4. premium_amount validations
  # ---------------------------------------------------------------------------
  describe "premium_amount" do
    it "is invalid when premium_amount is zero" do
      user = valid_user
      policy = build_policy(user, premium_amount: 0)
      expect(policy).not_to be_valid
      expect(policy.errors[:premium_amount]).to be_present
    end

    it "is invalid when premium_amount is negative" do
      user = valid_user
      policy = build_policy(user, premium_amount: -1)
      expect(policy).not_to be_valid
      expect(policy.errors[:premium_amount]).to be_present
    end

    it "is invalid when premium_amount is a decimal" do
      user = valid_user
      policy = build_policy(user, premium_amount: 100.5)
      expect(policy).not_to be_valid
      expect(policy.errors[:premium_amount]).to be_present
    end

    it "is valid when premium_amount is a positive integer" do
      user = valid_user
      policy = build_policy(user, premium_amount: 1)
      expect(policy).to be_valid
    end
  end

  # ---------------------------------------------------------------------------
  # 5. policy_type validations
  # ---------------------------------------------------------------------------
  describe "policy_type" do
    it "is invalid with an unrecognised policy_type" do
      user = valid_user
      policy = build_policy(user, policy_type: "life")
      expect(policy).not_to be_valid
      expect(policy.errors[:policy_type]).to be_present
    end

    it "is invalid with a blank policy_type" do
      user = valid_user
      policy = build_policy(user, policy_type: "")
      expect(policy).not_to be_valid
      expect(policy.errors[:policy_type]).to be_present
    end

    %w[term health auto bike].each do |type|
      it "is valid with policy_type '#{type}'" do
        user = valid_user
        policy = build_policy(user, policy_type: type)
        expect(policy).to be_valid
      end
    end
  end

  # ---------------------------------------------------------------------------
  # 6. premium_frequency validations
  # ---------------------------------------------------------------------------
  describe "premium_frequency" do
    it "is invalid with an unrecognised premium_frequency" do
      user = valid_user
      policy = build_policy(user, premium_frequency: "weekly")
      expect(policy).not_to be_valid
      expect(policy.errors[:premium_frequency]).to be_present
    end

    it "is invalid with a blank premium_frequency" do
      user = valid_user
      policy = build_policy(user, premium_frequency: "")
      expect(policy).not_to be_valid
      expect(policy.errors[:premium_frequency]).to be_present
    end

    %w[monthly quarterly half_yearly annually].each do |freq|
      it "is valid with premium_frequency '#{freq}'" do
        user = valid_user
        policy = build_policy(user, premium_frequency: freq)
        expect(policy).to be_valid
      end
    end
  end

  # ---------------------------------------------------------------------------
  # 7. Custom validation: renewal_date_must_be_in_future
  # ---------------------------------------------------------------------------
  describe "renewal_date_must_be_in_future" do
    # Use an explicit anchor date so travel_to controls both the spec and the
    # model's Date.current call consistently.
    let(:anchor_date) { Date.new(2025, 6, 1) }

    context "on create" do
      it "is invalid when renewal_date is in the past" do
        travel_to(anchor_date) do
          user = valid_user
          policy = build_policy(user, renewal_date: anchor_date - 1)
          expect(policy).not_to be_valid
          expect(policy.errors[:renewal_date]).to include("must be in the future")
        end
      end

      it "is invalid when renewal_date is today" do
        travel_to(anchor_date) do
          user = valid_user
          policy = build_policy(user, renewal_date: anchor_date)
          expect(policy).not_to be_valid
          expect(policy.errors[:renewal_date]).to include("must be in the future")
        end
      end

      it "is valid when renewal_date is in the future" do
        travel_to(anchor_date) do
          user = valid_user
          policy = build_policy(user, renewal_date: anchor_date + 1)
          expect(policy).to be_valid
        end
      end
    end

    context "on update" do
      it "is invalid when renewal_date is changed to a past date" do
        travel_to(anchor_date) do
          user = valid_user
          policy = create_policy(user, renewal_date: anchor_date + 365)
          policy.renewal_date = anchor_date - 1
          expect(policy).not_to be_valid
          expect(policy.errors[:renewal_date]).to include("must be in the future")
        end
      end

      it "is valid when renewal_date is NOT changed, even if the stored date is in the past" do
        user = valid_user
        # Create with a future date
        travel_to(anchor_date) do
          create_policy(user, renewal_date: anchor_date + 1)
        end

        # Travel forward so the stored renewal_date is now in the past
        travel_to(anchor_date + 2) do
          policy = InsurancePolicy.for_user(user).first
          # Update a different field without touching renewal_date
          policy.institution_name = "Updated Insurer"
          expect(policy).to be_valid
        end
      end

      it "is valid when renewal_date is changed to a future date" do
        travel_to(anchor_date) do
          user = valid_user
          policy = create_policy(user, renewal_date: anchor_date + 365)
          policy.renewal_date = anchor_date + 730
          expect(policy).to be_valid
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # 8. Constants
  # ---------------------------------------------------------------------------
  describe "POLICY_TYPES" do
    it "contains exactly 'term', 'health', 'auto', and 'bike'" do
      expect(InsurancePolicy::POLICY_TYPES).to eq(%w[term health auto bike])
    end

    it "is frozen" do
      expect(InsurancePolicy::POLICY_TYPES).to be_frozen
    end
  end

  describe "PREMIUM_FREQUENCIES" do
    it "contains exactly 'monthly', 'quarterly', 'half_yearly', and 'annually'" do
      expect(InsurancePolicy::PREMIUM_FREQUENCIES).to eq(%w[monthly quarterly half_yearly annually])
    end

    it "is frozen" do
      expect(InsurancePolicy::PREMIUM_FREQUENCIES).to be_frozen
    end
  end

  # ---------------------------------------------------------------------------
  # 9. for_user scope
  # ---------------------------------------------------------------------------
  describe ".for_user scope" do
    it "returns only policies belonging to the given user" do
      user_a = valid_user
      user_b = User.create!(identifier: "+14155559999", password: "securepass")

      create_policy(user_a)
      create_policy(user_b, policy_number: "POL-2024-002")

      result = InsurancePolicy.for_user(user_a)
      expect(result.count).to eq(1)
      expect(result.first.user).to eq(user_a)
    end

    it "returns an empty relation when the user has no insurance policies" do
      user = valid_user
      expect(InsurancePolicy.for_user(user)).to be_empty
    end

    it "returns all policies for a user when they have multiple" do
      user = valid_user
      create_policy(user, policy_number: "POL-001")
      create_policy(user, policy_number: "POL-002")

      expect(InsurancePolicy.for_user(user).count).to eq(2)
    end
  end

  # ---------------------------------------------------------------------------
  # 10. Associations
  # ---------------------------------------------------------------------------
  describe "associations" do
    it "belongs to a user" do
      user = valid_user
      policy = create_policy(user)
      expect(policy.user).to eq(user)
    end

    it "has many insured_members" do
      user = valid_user
      policy = create_policy(user)
      member = policy.insured_members.create!(name: "Jane Doe")
      expect(policy.insured_members).to include(member)
    end

    it "destroys associated insured_members when the policy is destroyed" do
      user = valid_user
      policy = create_policy(user)
      member = policy.insured_members.create!(name: "Jane Doe")
      member_id = member.id

      policy.destroy

      expect(InsuredMember.find_by(id: member_id)).to be_nil
    end

    it "is destroyed when the owning user is destroyed" do
      user = valid_user
      policy = create_policy(user)
      policy_id = policy.id

      User.where(id: user.id).delete_all

      expect(InsurancePolicy.find_by(id: policy_id)).to be_nil
    end
  end
end
