# frozen_string_literal: true

require "rails_helper"

RSpec.describe User, type: :model do
  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------
  def valid_phone_attrs(overrides = {})
    { identifier: "+14155552671", password: "securepass" }.merge(overrides)
  end

  def valid_email_attrs(overrides = {})
    { identifier: "user@example.com", password: "securepass" }.merge(overrides)
  end

  # ---------------------------------------------------------------------------
  # 1. Valid identifiers are accepted
  # ---------------------------------------------------------------------------
  describe "valid identifiers" do
    it "accepts a valid E.164 phone number" do
      user = User.new(valid_phone_attrs)
      expect(user).to be_valid
    end

    it "accepts a valid email address" do
      user = User.new(valid_email_attrs)
      expect(user).to be_valid
    end

    it "accepts international E.164 numbers" do
      ["+447911123456", "+819012345678", "+5511987654321"].each do |phone|
        user = User.new(valid_phone_attrs(identifier: phone))
        expect(user).to be_valid, "expected #{phone} to be valid"
      end
    end

    it "accepts various valid email formats" do
      ["a@b.co", "first.last+tag@sub.domain.org"].each do |email|
        user = User.new(valid_email_attrs(identifier: email))
        expect(user).to be_valid, "expected #{email} to be valid"
      end
    end
  end

  # ---------------------------------------------------------------------------
  # 2. Invalid identifier formats are rejected
  # ---------------------------------------------------------------------------
  describe "invalid identifiers" do
    it "rejects a phone number without leading +" do
      user = User.new(valid_phone_attrs(identifier: "14155552671"))
      expect(user).not_to be_valid
      expect(user.errors[:identifier]).to be_present
    end

    it "rejects a phone number that is too short" do
      user = User.new(valid_phone_attrs(identifier: "+123"))
      expect(user).not_to be_valid
    end

    it "rejects a plain string that is neither phone nor email" do
      user = User.new(valid_phone_attrs(identifier: "not-an-identifier"))
      expect(user).not_to be_valid
      expect(user.errors[:identifier]).to be_present
    end

    it "rejects an email missing the @ symbol" do
      user = User.new(valid_email_attrs(identifier: "userexample.com"))
      expect(user).not_to be_valid
    end

    it "rejects a blank identifier" do
      user = User.new(valid_phone_attrs(identifier: ""))
      expect(user).not_to be_valid
      expect(user.errors[:identifier]).to be_present
    end
  end

  # ---------------------------------------------------------------------------
  # 3. identifier_type is auto-inferred
  # ---------------------------------------------------------------------------
  describe "#identifier_type inference" do
    it "sets identifier_type to 'phone' for an E.164 number" do
      user = User.new(valid_phone_attrs)
      user.valid?
      expect(user.identifier_type).to eq("phone")
    end

    it "sets identifier_type to 'email' for an email address" do
      user = User.new(valid_email_attrs)
      user.valid?
      expect(user.identifier_type).to eq("email")
    end

    it "leaves identifier_type nil for an unrecognised identifier" do
      user = User.new(valid_phone_attrs(identifier: "garbage"))
      user.valid?
      expect(user.identifier_type).to be_nil
    end
  end

  # ---------------------------------------------------------------------------
  # 4 & 5. Password length validation
  # ---------------------------------------------------------------------------
  describe "password length" do
    it "rejects a password shorter than 8 characters" do
      user = User.new(valid_email_attrs(password: "short"))
      expect(user).not_to be_valid
      expect(user.errors[:password]).to be_present
    end

    it "rejects a 7-character password" do
      user = User.new(valid_email_attrs(password: "1234567"))
      expect(user).not_to be_valid
    end

    it "accepts a password of exactly 8 characters" do
      user = User.new(valid_email_attrs(password: "12345678"))
      expect(user).to be_valid
    end

    it "accepts a password longer than 8 characters" do
      user = User.new(valid_email_attrs(password: "a_very_long_password_123"))
      expect(user).to be_valid
    end
  end

  # ---------------------------------------------------------------------------
  # 6. Duplicate identifier (case-insensitive) is rejected
  # ---------------------------------------------------------------------------
  describe "uniqueness of identifier" do
    it "rejects a duplicate identifier with the same case" do
      User.create!(valid_email_attrs)
      duplicate = User.new(valid_email_attrs)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:identifier]).to be_present
    end

    it "rejects a duplicate email identifier regardless of case" do
      User.create!(valid_email_attrs(identifier: "User@Example.com"))
      duplicate = User.new(valid_email_attrs(identifier: "user@example.com"))
      expect(duplicate).not_to be_valid
    end

    it "rejects a duplicate phone identifier regardless of case" do
      User.create!(valid_phone_attrs(identifier: "+14155552671"))
      duplicate = User.new(valid_phone_attrs(identifier: "+14155552671"))
      expect(duplicate).not_to be_valid
    end
  end

  # ---------------------------------------------------------------------------
  # 7. verified defaults to false
  # ---------------------------------------------------------------------------
  describe "verified default" do
    it "defaults verified to false on a new record" do
      user = User.new(valid_email_attrs)
      expect(user.verified).to be(false)
    end

    it "persists verified as false when not explicitly set" do
      user = User.create!(valid_email_attrs)
      expect(user.reload.verified).to be(false)
    end
  end

  # ---------------------------------------------------------------------------
  # 8. password_digest is not the plaintext password
  # ---------------------------------------------------------------------------
  describe "password storage" do
    it "stores a bcrypt digest, not the plaintext password" do
      user = User.create!(valid_email_attrs(password: "securepass"))
      expect(user.password_digest).not_to eq("securepass")
      expect(user.password_digest).to start_with("$2a$").or(start_with("$2b$"))
    end

    it "authenticates correctly with the original password" do
      user = User.create!(valid_email_attrs(password: "securepass"))
      expect(user.authenticate("securepass")).to eq(user)
    end

    it "does not authenticate with a wrong password" do
      user = User.create!(valid_email_attrs(password: "securepass"))
      expect(user.authenticate("wrongpass")).to be(false)
    end
  end
end
