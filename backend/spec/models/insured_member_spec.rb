# frozen_string_literal: true

require "rails_helper"

RSpec.describe InsuredMember, type: :model do
  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  def valid_user
    User.create!(identifier: "+14155552671", password: "securepass")
  end

  def valid_policy_attrs(overrides = {})
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

  def create_policy(user, overrides = {})
    user.insurance_policies.create!(valid_policy_attrs(overrides))
  end

  def build_member(policy, overrides = {})
    policy.insured_members.build({ name: "Jane Doe" }.merge(overrides))
  end

  def create_member(policy, overrides = {})
    policy.insured_members.create!({ name: "Jane Doe" }.merge(overrides))
  end

  # ---------------------------------------------------------------------------
  # 1. Valid member
  # ---------------------------------------------------------------------------
  describe "valid insured member" do
    it "is valid with a name and an insurance_policy" do
      user = valid_user
      policy = create_policy(user)
      member = build_member(policy)
      expect(member).to be_valid
    end

    it "is valid when member_identifier is provided" do
      user = valid_user
      policy = create_policy(user)
      member = build_member(policy, member_identifier: "MEM-001")
      expect(member).to be_valid
    end

    it "is valid when member_identifier is nil" do
      user = valid_user
      policy = create_policy(user)
      member = build_member(policy, member_identifier: nil)
      expect(member).to be_valid
    end
  end

  # ---------------------------------------------------------------------------
  # 2. name presence validation
  # ---------------------------------------------------------------------------
  describe "name presence validation" do
    it "is invalid when name is blank" do
      user = valid_user
      policy = create_policy(user)
      member = build_member(policy, name: "")
      expect(member).not_to be_valid
      expect(member.errors[:name]).to be_present
    end

    it "is invalid when name is nil" do
      user = valid_user
      policy = create_policy(user)
      member = build_member(policy, name: nil)
      expect(member).not_to be_valid
      expect(member.errors[:name]).to be_present
    end
  end

  # ---------------------------------------------------------------------------
  # 3. member_identifier is optional
  # ---------------------------------------------------------------------------
  describe "member_identifier" do
    it "is optional — nil is valid" do
      user = valid_user
      policy = create_policy(user)
      member = build_member(policy, member_identifier: nil)
      expect(member).to be_valid
    end

    it "persists nil member_identifier without error" do
      user = valid_user
      policy = create_policy(user)
      member = create_member(policy, member_identifier: nil)
      expect(member.reload.member_identifier).to be_nil
    end

    it "persists a provided member_identifier" do
      user = valid_user
      policy = create_policy(user)
      member = create_member(policy, member_identifier: "MEM-42")
      expect(member.reload.member_identifier).to eq("MEM-42")
    end
  end

  # ---------------------------------------------------------------------------
  # 4. belongs_to insurance_policy association
  # ---------------------------------------------------------------------------
  describe "associations" do
    it "belongs to an insurance_policy" do
      user = valid_user
      policy = create_policy(user)
      member = create_member(policy)
      expect(member.insurance_policy).to eq(policy)
    end

    it "is invalid without an insurance_policy" do
      member = InsuredMember.new(name: "Jane Doe")
      expect(member).not_to be_valid
      expect(member.errors[:insurance_policy]).to be_present
    end
  end

  # ---------------------------------------------------------------------------
  # 5. Destroyed when parent insurance_policy is destroyed
  # ---------------------------------------------------------------------------
  describe "dependent destroy" do
    it "is destroyed when the parent insurance_policy is destroyed" do
      user = valid_user
      policy = create_policy(user)
      member = create_member(policy)
      member_id = member.id

      policy.destroy

      expect(InsuredMember.find_by(id: member_id)).to be_nil
    end

    it "all members are destroyed when the parent policy is destroyed" do
      user = valid_user
      policy = create_policy(user)
      create_member(policy, name: "Alice")
      create_member(policy, name: "Bob")

      expect { policy.destroy }.to change(InsuredMember, :count).by(-2)
    end
  end
end
