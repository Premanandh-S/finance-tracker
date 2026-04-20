# frozen_string_literal: true

require "rails_helper"

RSpec.describe Auth::SessionService do
  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------
  def create_user(overrides = {})
    User.create!({ identifier: "user@example.com", password: "securepass" }.merge(overrides))
  end

  let(:user) { create_user }

  # ---------------------------------------------------------------------------
  # .issue_jwt
  # ---------------------------------------------------------------------------
  describe ".issue_jwt" do
    it "returns a String" do
      token = described_class.issue_jwt(user)
      expect(token).to be_a(String)
    end

    it "returns a non-empty string" do
      token = described_class.issue_jwt(user)
      expect(token).not_to be_empty
    end

    it "encodes the user id as the 'sub' claim (string)" do
      freeze_time do
        token = described_class.issue_jwt(user)
        payload = JWT.decode(token, Rails.application.credentials.secret_key_base || ENV["SECRET_KEY_BASE"], true, { algorithm: "HS256" }).first
        expect(payload["sub"]).to eq(user.id.to_s)
      end
    end

    it "includes a UUID v4 'jti' claim" do
      token = described_class.issue_jwt(user)
      payload = JWT.decode(token, Rails.application.credentials.secret_key_base || ENV["SECRET_KEY_BASE"], true, { algorithm: "HS256" }).first
      expect(payload["jti"]).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/i)
    end

    it "sets 'iat' to the current time as an integer" do
      freeze_time do
        token = described_class.issue_jwt(user)
        payload = JWT.decode(token, Rails.application.credentials.secret_key_base || ENV["SECRET_KEY_BASE"], true, { algorithm: "HS256" }).first
        expect(payload["iat"]).to eq(Time.now.to_i)
      end
    end

    it "sets 'exp' to exactly 24 hours after 'iat'" do
      freeze_time do
        token = described_class.issue_jwt(user)
        payload = JWT.decode(token, Rails.application.credentials.secret_key_base || ENV["SECRET_KEY_BASE"], true, { algorithm: "HS256" }).first
        expect(payload["exp"]).to eq(payload["iat"] + 86_400)
      end
    end

    it "signs the token with HS256" do
      token = described_class.issue_jwt(user)
      # JWT header is the first segment; pad to a multiple of 4 for Base64 decoding
      header_segment = token.split(".").first
      padded = header_segment + "=" * ((4 - header_segment.length % 4) % 4)
      header = JSON.parse(Base64.urlsafe_decode64(padded))
      expect(header["alg"]).to eq("HS256")
    end

    it "issues a different jti on each call" do
      token1 = described_class.issue_jwt(user)
      token2 = described_class.issue_jwt(user)
      secret = Rails.application.credentials.secret_key_base || ENV["SECRET_KEY_BASE"]
      jti1 = JWT.decode(token1, secret, true, { algorithm: "HS256" }).first["jti"]
      jti2 = JWT.decode(token2, secret, true, { algorithm: "HS256" }).first["jti"]
      expect(jti1).not_to eq(jti2)
    end
  end

  # ---------------------------------------------------------------------------
  # .verify_jwt
  # ---------------------------------------------------------------------------
  describe ".verify_jwt" do
    context "with a valid token" do
      it "returns the payload hash" do
        token = described_class.issue_jwt(user)
        payload = described_class.verify_jwt(token)
        expect(payload).to be_a(Hash)
      end

      it "payload contains the correct 'sub'" do
        token = described_class.issue_jwt(user)
        payload = described_class.verify_jwt(token)
        expect(payload["sub"]).to eq(user.id.to_s)
      end

      it "payload contains 'jti', 'iat', and 'exp' keys" do
        token = described_class.issue_jwt(user)
        payload = described_class.verify_jwt(token)
        expect(payload.keys).to include("jti", "iat", "exp")
      end
    end

    context "with an expired token" do
      it "raises ExpiredTokenError" do
        token = described_class.issue_jwt(user)
        travel_to(25.hours.from_now) do
          expect { described_class.verify_jwt(token) }
            .to raise_error(Auth::SessionService::ExpiredTokenError)
        end
      end
    end

    context "with a tampered token" do
      it "raises InvalidTokenError when the signature is modified" do
        token = described_class.issue_jwt(user)
        tampered = token[0..-5] + "XXXX"
        expect { described_class.verify_jwt(tampered) }
          .to raise_error(Auth::SessionService::InvalidTokenError)
      end

      it "raises InvalidTokenError for a completely invalid string" do
        expect { described_class.verify_jwt("not.a.jwt") }
          .to raise_error(Auth::SessionService::InvalidTokenError)
      end
    end

    context "with a denylisted token" do
      it "raises DenylistedTokenError" do
        token = described_class.issue_jwt(user)
        described_class.invalidate_jwt(token)
        expect { described_class.verify_jwt(token) }
          .to raise_error(Auth::SessionService::DenylistedTokenError)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # .refresh_jwt
  # ---------------------------------------------------------------------------
  describe ".refresh_jwt" do
    it "returns a new token string" do
      token = described_class.issue_jwt(user)
      new_token = described_class.refresh_jwt(token)
      expect(new_token).to be_a(String)
      expect(new_token).not_to be_empty
    end

    it "returns a different token than the original" do
      token = described_class.issue_jwt(user)
      new_token = described_class.refresh_jwt(token)
      expect(new_token).not_to eq(token)
    end

    it "the new token is valid and verifiable" do
      token = described_class.issue_jwt(user)
      new_token = described_class.refresh_jwt(token)
      expect { described_class.verify_jwt(new_token) }.not_to raise_error
    end

    it "the new token carries the same 'sub' as the original" do
      token = described_class.issue_jwt(user)
      new_token = described_class.refresh_jwt(token)
      new_payload = described_class.verify_jwt(new_token)
      expect(new_payload["sub"]).to eq(user.id.to_s)
    end

    it "denylists the old token after refresh" do
      token = described_class.issue_jwt(user)
      described_class.refresh_jwt(token)
      expect { described_class.verify_jwt(token) }
        .to raise_error(Auth::SessionService::DenylistedTokenError)
    end

    it "raises ExpiredTokenError when the original token is expired" do
      token = described_class.issue_jwt(user)
      travel_to(25.hours.from_now) do
        expect { described_class.refresh_jwt(token) }
          .to raise_error(Auth::SessionService::ExpiredTokenError)
      end
    end

    it "raises DenylistedTokenError when the original token is already denylisted" do
      token = described_class.issue_jwt(user)
      described_class.invalidate_jwt(token)
      expect { described_class.refresh_jwt(token) }
        .to raise_error(Auth::SessionService::DenylistedTokenError)
    end
  end

  # ---------------------------------------------------------------------------
  # .invalidate_jwt
  # ---------------------------------------------------------------------------
  describe ".invalidate_jwt" do
    it "returns nil" do
      token = described_class.issue_jwt(user)
      expect(described_class.invalidate_jwt(token)).to be_nil
    end

    it "adds the token's jti to JwtDenylist" do
      token = described_class.issue_jwt(user)
      secret = Rails.application.credentials.secret_key_base || ENV["SECRET_KEY_BASE"]
      jti = JWT.decode(token, secret, true, { algorithm: "HS256" }).first["jti"]

      expect { described_class.invalidate_jwt(token) }
        .to change { JwtDenylist.denylisted?(jti) }.from(false).to(true)
    end

    it "causes subsequent verify_jwt to raise DenylistedTokenError" do
      token = described_class.issue_jwt(user)
      described_class.invalidate_jwt(token)
      expect { described_class.verify_jwt(token) }
        .to raise_error(Auth::SessionService::DenylistedTokenError)
    end

    it "is idempotent — calling twice does not raise" do
      token = described_class.issue_jwt(user)
      described_class.invalidate_jwt(token)
      expect { described_class.invalidate_jwt(token) }.not_to raise_error
    end

    it "raises InvalidTokenError for a malformed token" do
      expect { described_class.invalidate_jwt("bad.token.here") }
        .to raise_error(Auth::SessionService::InvalidTokenError)
    end
  end
end
