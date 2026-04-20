# frozen_string_literal: true

require "rails_helper"

RSpec.describe Auth::OtpDeliveryService do
  let(:code) { "123456" }

  describe "#deliver" do
    context "when user has a phone identifier" do
      let(:user) { instance_double("User", phone?: true, email?: false, identifier_type: "phone") }

      it "routes to the SMS path without raising" do
        service = described_class.new(user)
        expect { service.deliver(code) }.not_to raise_error
      end
    end

    context "when user has an email identifier" do
      let(:user) { instance_double("User", phone?: false, email?: true, identifier_type: "email") }

      it "routes to the email path without raising" do
        service = described_class.new(user)
        expect { service.deliver(code) }.not_to raise_error
      end
    end

    context "when the provider raises an error" do
      let(:user) { instance_double("User", phone?: true, email?: false, identifier_type: "phone") }

      it "raises DeliveryError" do
        service = described_class.new(user)
        allow(service).to receive(:deliver_via_sms).and_raise(
          Auth::OtpDeliveryService::DeliveryError, "SMS provider unavailable"
        )
        expect { service.deliver(code) }.to raise_error(Auth::OtpDeliveryService::DeliveryError, "SMS provider unavailable")
      end
    end

    context "when identifier_type is unknown" do
      let(:user) { instance_double("User", phone?: false, email?: false, identifier_type: "unknown") }

      it "raises DeliveryError" do
        service = described_class.new(user)
        expect { service.deliver(code) }.to raise_error(Auth::OtpDeliveryService::DeliveryError, /Unknown identifier type/)
      end
    end
  end
end
