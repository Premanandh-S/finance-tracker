# frozen_string_literal: true

require "rails_helper"

RSpec.describe "POST /auth/register", type: :request do
  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  def register(identifier:, password: nil)
    body = { identifier: identifier }
    body[:password] = password if password
    post "/auth/register", params: body, as: :json
  end

  def stub_otp_delivery!
    delivery_double = instance_double(Auth::OtpDeliveryService, deliver: nil)
    allow(Auth::OtpDeliveryService).to receive(:new).and_return(delivery_double)
  end

  # ---------------------------------------------------------------------------
  # 5.1 — POST /auth/register
  # ---------------------------------------------------------------------------

  describe "success" do
    before { stub_otp_delivery! }

    it "returns 201 with a valid email identifier" do
      register(identifier: "user@example.com")

      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body)).to include("message")
    end

    it "returns 201 with a valid E.164 phone identifier" do
      register(identifier: "+14155552671")

      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body)).to include("message")
    end

    it "creates a user record in the database" do
      expect { register(identifier: "newuser@example.com") }
        .to change(User, :count).by(1)
    end

    it "creates the user as unverified" do
      register(identifier: "unverified@example.com")

      user = User.find_by(identifier: "unverified@example.com")
      expect(user.verified).to be(false)
    end
  end

  describe "duplicate identifier" do
    before do
      stub_otp_delivery!
      User.create!(identifier: "taken@example.com", verified: false)
    end

    it "returns 422" do
      register(identifier: "taken@example.com")

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "returns identifier_taken error code" do
      register(identifier: "taken@example.com")

      body = JSON.parse(response.body)
      expect(body["error"]).to eq("identifier_taken")
      expect(body).to have_key("message")
    end

    it "does not create a second user record" do
      expect { register(identifier: "taken@example.com") }
        .not_to change(User, :count)
    end
  end

  describe "invalid identifier format" do
    before { stub_otp_delivery! }

    it "returns 422 for an invalid email format" do
      register(identifier: "not-an-email")

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "returns invalid_identifier error code for bad email" do
      register(identifier: "not-an-email")

      body = JSON.parse(response.body)
      expect(body["error"]).to eq("invalid_identifier")
      expect(body).to have_key("message")
    end

    it "returns 422 for an invalid phone format" do
      register(identifier: "12345")

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "returns invalid_identifier error code for bad phone" do
      register(identifier: "12345")

      body = JSON.parse(response.body)
      expect(body["error"]).to eq("invalid_identifier")
    end

    it "does not create a user record for invalid identifier" do
      expect { register(identifier: "not-an-email") }
        .not_to change(User, :count)
    end
  end
end
