# frozen_string_literal: true

Rails.application.routes.draw do
  # --- Dev email preview ---
  if Rails.env.development?
    mount LetterOpenerWeb::Engine, at: "/letter_opener"
  end

  get "dashboard", to: "dashboard#show"

  resources :loans, only: %i[index show create update destroy] do
    resources :interest_rate_periods, only: %i[create update destroy],
                                      module: :loans
  end

  resources :savings_instruments, only: %i[index show create update destroy]

  resources :insurance_policies, only: %i[index show create update destroy] do
    resources :insured_members, only: %i[create update destroy],
                                module: :insurance_policies
  end

  resources :pension_instruments, only: %i[index show create update destroy] do
    resources :pension_contributions, only: %i[create update destroy],
                                      module: :pension_instruments
  end

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
