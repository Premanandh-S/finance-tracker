# frozen_string_literal: true

require "rails_helper"

RSpec.describe OtpCode, type: :model do
  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------
  def valid_user_attrs(overrides = {})
    { identifier: "user@example.com", password: "securepass" }.merge(overrides)
  end

  def valid_otp_attrs(user, overrides = {})
    {
      user:         user,
      code_digest:  "$2a$12#{"x" * 53}",
      expires_at:   10.minutes.from_now,
      used:         false
    }.merge(overrides)
  end

  # ---------------------------------------------------------------------------
  # 1. Association
  # ---------------------------------------------------------------------------
  describe "associations" do
    it "belongs to a user" do
      association = described_class.reflect_on_association(:user)
      expect(association.macro).to eq(:belongs_to)
    end
  end

  # ---------------------------------------------------------------------------
  # 2. Validations
  # ---------------------------------------------------------------------------
  describe "validations" do
    let(:user) { User.create!(valid_user_attrs) }

    it "is valid with all required attributes" do
      otp = OtpCode.new(valid_otp_attrs(user))
      expect(otp).to be_valid
    end

    it "requires user_id" do
      otp = OtpCode.new(valid_otp_attrs(user).except(:user))
      expect(otp).not_to be_valid
      expect(otp.errors[:user]).to be_present
    end

    it "requires code_digest" do
      otp = OtpCode.new(valid_otp_attrs(user, code_digest: nil))
      expect(otp).not_to be_valid
      expect(otp.errors[:code_digest]).to be_present
    end

    it "requires expires_at" do
      otp = OtpCode.new(valid_otp_attrs(user, expires_at: nil))
      expect(otp).not_to be_valid
      expect(otp.errors[:expires_at]).to be_present
    end
  end

  # ---------------------------------------------------------------------------
  # 3. Scopes
  # ---------------------------------------------------------------------------
  describe "scopes" do
    let(:user) { User.create!(valid_user_attrs) }

    describe ".active" do
      it "returns unused, unexpired records" do
        active = OtpCode.create!(valid_otp_attrs(user, expires_at: 10.minutes.from_now, used: false))
        expect(OtpCode.active).to include(active)
      end

      it "excludes used records" do
        used = OtpCode.create!(valid_otp_attrs(user, expires_at: 10.minutes.from_now, used: true))
        expect(OtpCode.active).not_to include(used)
      end

      it "excludes expired records" do
        expired = OtpCode.create!(valid_otp_attrs(user, expires_at: 10.minutes.ago, used: false))
        expect(OtpCode.active).not_to include(expired)
      end
    end

    describe ".expired" do
      it "returns records whose expires_at is in the past" do
        expired = OtpCode.create!(valid_otp_attrs(user, expires_at: 1.minute.ago))
        expect(OtpCode.expired).to include(expired)
      end

      it "excludes records that have not yet expired" do
        fresh = OtpCode.create!(valid_otp_attrs(user, expires_at: 10.minutes.from_now))
        expect(OtpCode.expired).not_to include(fresh)
      end
    end

    describe ".used" do
      it "returns records marked as used" do
        used = OtpCode.create!(valid_otp_attrs(user, used: true))
        expect(OtpCode.used).to include(used)
      end

      it "excludes records that are not used" do
        unused = OtpCode.create!(valid_otp_attrs(user, used: false))
        expect(OtpCode.used).not_to include(unused)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # 4. #expired?
  # ---------------------------------------------------------------------------
  describe "#expired?" do
    it "returns true when expires_at is in the past" do
      otp = OtpCode.new(expires_at: 1.second.ago)
      expect(otp.expired?).to be(true)
    end

    it "returns false when expires_at is in the future" do
      otp = OtpCode.new(expires_at: 1.minute.from_now)
      expect(otp.expired?).to be(false)
    end
  end

  # ---------------------------------------------------------------------------
  # 5. #active?
  # ---------------------------------------------------------------------------
  describe "#active?" do
    it "returns true when unused and unexpired" do
      otp = OtpCode.new(used: false, expires_at: 10.minutes.from_now)
      expect(otp.active?).to be(true)
    end

    it "returns false when used" do
      otp = OtpCode.new(used: true, expires_at: 10.minutes.from_now)
      expect(otp.active?).to be(false)
    end

    it "returns false when expired" do
      otp = OtpCode.new(used: false, expires_at: 1.minute.ago)
      expect(otp.active?).to be(false)
    end

    it "returns false when both used and expired" do
      otp = OtpCode.new(used: true, expires_at: 1.minute.ago)
      expect(otp.active?).to be(false)
    end
  end
end
