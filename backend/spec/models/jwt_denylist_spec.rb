# frozen_string_literal: true

require "rails_helper"

RSpec.describe JwtDenylist, type: :model do
  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------
  def valid_attrs(overrides = {})
    {
      jti: SecureRandom.uuid,
      exp: 24.hours.from_now
    }.merge(overrides)
  end

  # ---------------------------------------------------------------------------
  # 1. Validations
  # ---------------------------------------------------------------------------
  describe "validations" do
    it "is valid with a jti and exp" do
      expect(JwtDenylist.new(valid_attrs)).to be_valid
    end

    it "requires jti" do
      record = JwtDenylist.new(valid_attrs(jti: nil))
      expect(record).not_to be_valid
      expect(record.errors[:jti]).to be_present
    end

    it "requires jti to be unique" do
      jti = SecureRandom.uuid
      JwtDenylist.create!(valid_attrs(jti: jti))
      duplicate = JwtDenylist.new(valid_attrs(jti: jti))
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:jti]).to be_present
    end

    it "requires exp" do
      record = JwtDenylist.new(valid_attrs(exp: nil))
      expect(record).not_to be_valid
      expect(record.errors[:exp]).to be_present
    end
  end

  # ---------------------------------------------------------------------------
  # 2. .by_jti scope
  # ---------------------------------------------------------------------------
  describe ".by_jti" do
    it "returns the record matching the given jti" do
      target = JwtDenylist.create!(valid_attrs)
      _other = JwtDenylist.create!(valid_attrs)

      result = JwtDenylist.by_jti(target.jti)
      expect(result).to include(target)
      expect(result.count).to eq(1)
    end

    it "returns an empty relation when no record matches" do
      expect(JwtDenylist.by_jti(SecureRandom.uuid)).to be_empty
    end
  end

  # ---------------------------------------------------------------------------
  # 3. .denylisted?
  # ---------------------------------------------------------------------------
  describe ".denylisted?" do
    it "returns true for a jti that exists in the denylist" do
      entry = JwtDenylist.create!(valid_attrs)
      expect(JwtDenylist.denylisted?(entry.jti)).to be(true)
    end

    it "returns false for a jti that does not exist in the denylist" do
      expect(JwtDenylist.denylisted?(SecureRandom.uuid)).to be(false)
    end
  end
end
