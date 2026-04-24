# frozen_string_literal: true

# Mailer for authentication-related emails.
#
# In development, emails are intercepted by letter_opener_web and viewable
# at http://localhost:3000/letter_opener — no real email is sent.
class AuthMailer < ApplicationMailer
  # Sends a one-time password to the user's email address.
  #
  # @param to [String] the recipient email address
  # @param code [String] the 6-digit OTP code
  # @return [Mail::Message]
  def otp_email(to:, code:)
    @code = code
    @expires_in = "10 minutes"
    mail(to: to, subject: "Your verification code: #{code}")
  end
end
