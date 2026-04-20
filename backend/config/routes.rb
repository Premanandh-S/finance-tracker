# frozen_string_literal: true

Rails.application.routes.draw do
  namespace :auth do
    post   "register",                to: "registrations#create"
    post   "otp/request",             to: "otp#request_otp"
    post   "otp/verify",              to: "otp#verify"
    post   "login",                   to: "sessions#create"
    delete "logout",                  to: "sessions#destroy"
    post   "refresh",                 to: "sessions#refresh"
    post   "password/reset/request",  to: "passwords#reset_request"
    post   "password/reset/confirm",  to: "passwords#reset_confirm"
  end
end
