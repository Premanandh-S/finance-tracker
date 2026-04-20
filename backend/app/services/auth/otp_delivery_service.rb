# frozen_string_literal: true

module Auth
  # Routes OTP delivery to the appropriate provider (SMS or email)
  # based on the user's identifier type.
  #
  # @example
  #   service = Auth::OtpDeliveryService.new(user)
  #   service.deliver("123456")
  class OtpDeliveryService
    # Raised when OTP delivery fails.
    class DeliveryError < StandardError; end

    # @param user [User] the user to deliver the OTP to
    def initialize(user)
      @user = user
    end

    # Delivers the OTP code to the user via SMS or email,
    # depending on the user's identifier type.
    #
    # @param code [String] the 6-digit OTP code to deliver
    # @return [void]
    # @raise [Auth::OtpDeliveryService::DeliveryError] if delivery fails
    def deliver(code)
      if @user.phone?
        deliver_via_sms(code)
      elsif @user.email?
        deliver_via_email(code)
      else
        raise DeliveryError, "Unknown identifier type: #{@user.identifier_type.inspect}"
      end
    end

    private

    # @param code [String] the OTP code
    # @return [void]
    # @raise [Auth::OtpDeliveryService::DeliveryError] if SMS delivery fails
    def deliver_via_sms(code)
      # TODO: integrate SMS provider (e.g., Twilio)
      # SmsProvider.deliver(to: @user.identifier, body: "Your OTP is #{code}")
    end

    # @param code [String] the OTP code
    # @return [void]
    # @raise [Auth::OtpDeliveryService::DeliveryError] if email delivery fails
    def deliver_via_email(code)
      # TODO: integrate Email provider (e.g., ActionMailer/SendGrid)
      # AuthMailer.otp_email(to: @user.identifier, code: code).deliver_now
    end
  end
end
