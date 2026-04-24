# frozen_string_literal: true

module Loans
  # Orchestrates CRUD operations for {Loan} records.
  #
  # This is a PORO module with class methods only — it holds no state.
  # All persistence is delegated to the {Loan} and {InterestRatePeriod} models;
  # all computation is delegated to {Loans::PaymentCalculator}.
  #
  # @example Create a fixed-rate loan
  #   loan = Loans::LoanManager.create(user: current_user, params: {
  #     institution_name:    "HDFC Bank",
  #     loan_identifier:     "HL-2024-001",
  #     outstanding_balance: 250_000_00,
  #     annual_interest_rate: 8.5,
  #     interest_rate_type:  "fixed",
  #     monthly_payment:     25_000_00,
  #     payment_due_day:     5
  #   })
  #
  # @example Create a floating-rate loan with rate periods
  #   loan = Loans::LoanManager.create(user: current_user, params: {
  #     institution_name:       "SBI",
  #     loan_identifier:        "HL-2024-002",
  #     outstanding_balance:    100_000_00,
  #     annual_interest_rate:   9.0,
  #     interest_rate_type:     "floating",
  #     monthly_payment:        10_000_00,
  #     payment_due_day:        10,
  #     interest_rate_periods:  [
  #       { start_date: "2024-01-01", annual_interest_rate: 9.0 }
  #     ]
  #   })
  module LoanManager
    # Raised when a requested loan does not exist or does not belong to the
    # requesting user. The message intentionally does not distinguish between
    # "not found" and "forbidden" to avoid leaking resource existence.
    class NotFoundError < StandardError; end

    # Raised when loan params fail model validations.
    #
    # @example Rescue and inspect field details
    #   rescue Loans::LoanManager::ValidationError => e
    #     e.message  # => "Validation failed"
    #     e.details  # => { "outstanding_balance" => ["must be greater than 0"] }
    class ValidationError < StandardError
      # @return [Hash] field-level error details from +model.errors.as_json+
      attr_reader :details

      # @param message [String] human-readable summary
      # @param details [Hash] field-level errors from +model.errors.as_json+
      def initialize(message = "Validation failed", details: {})
        super(message)
        @details = details
      end
    end

    # Returns full detail for a single loan belonging to the given user,
    # including the computed amortisation schedule.
    #
    # @param user [User] the authenticated user requesting the loan
    # @param loan_id [Integer] the ID of the loan to retrieve
    # @return [Hash] full loan detail including +:amortisation_schedule+ and
    #   +:interest_rate_periods+
    # @raise [Loans::LoanManager::NotFoundError] when the loan does not exist or
    #   belongs to a different user
    def self.show(user:, loan_id:)
      loan = user.loans.find_by(id: loan_id)
      raise NotFoundError, "Loan not found" unless loan

      {
        id:                    loan.id,
        institution_name:      loan.institution_name,
        loan_identifier:       loan.loan_identifier,
        outstanding_balance:   loan.outstanding_balance,
        interest_rate_type:    loan.interest_rate_type,
        annual_interest_rate:  loan.annual_interest_rate,
        monthly_payment:       loan.monthly_payment,
        payment_due_day:       loan.payment_due_day,
        next_payment_date:     Loans::PaymentCalculator.next_payment_date(loan),
        payoff_date:           Loans::PaymentCalculator.payoff_date(loan),
        interest_rate_periods: loan.interest_rate_periods.map do |p|
          {
            id:                   p.id,
            start_date:           p.start_date,
            end_date:             p.end_date,
            annual_interest_rate: p.annual_interest_rate
          }
        end,
        amortisation_schedule: Loans::PaymentCalculator.amortisation_schedule(loan)
      }
    end

    # Returns a list of loans belonging to the given user, each decorated with
    # computed +next_payment_date+ and +payoff_date+ values.
    #
    # @param user [User] the authenticated user whose loans are listed
    # @return [Array<Hash>] one hash per loan; includes all loan fields plus
    #   +:next_payment_date+ and +:payoff_date+. Returns an empty array when
    #   the user has no loans.
    def self.list(user:)
      user.loans.map do |loan|
        {
          id:                   loan.id,
          institution_name:     loan.institution_name,
          loan_identifier:      loan.loan_identifier,
          outstanding_balance:  loan.outstanding_balance,
          interest_rate_type:   loan.interest_rate_type,
          annual_interest_rate: loan.annual_interest_rate,
          monthly_payment:      loan.monthly_payment,
          next_payment_date:    Loans::PaymentCalculator.next_payment_date(loan),
          payoff_date:          Loans::PaymentCalculator.payoff_date(loan)
        }
      end
    end

    # Updates an existing {Loan} belonging to the given user.
    #
    # @param user [User] the authenticated user who owns the loan
    # @param loan_id [Integer] the ID of the loan to update
    # @param params [Hash] loan attributes to update
    # @return [Loan] the updated loan record
    # @raise [Loans::LoanManager::NotFoundError] when the loan does not exist or
    #   belongs to a different user
    # @raise [Loans::LoanManager::ValidationError] when any model validation fails
    def self.update(user:, loan_id:, params:)
      loan = user.loans.find_by(id: loan_id)
      raise NotFoundError, "Loan not found" unless loan

      loan.assign_attributes(params)

      unless loan.save
        raise ValidationError.new(
          loan.errors.full_messages.first || "Validation failed",
          details: loan.errors.as_json.transform_keys(&:to_s)
        )
      end

      loan
    end

    # Permanently deletes a {Loan} belonging to the given user, along with all
    # associated {InterestRatePeriod} records (via +dependent: :destroy+).
    #
    # @param user [User] the authenticated user who owns the loan
    # @param loan_id [Integer] the ID of the loan to delete
    # @return [nil]
    # @raise [Loans::LoanManager::NotFoundError] when the loan does not exist or
    #   belongs to a different user
    def self.destroy(user:, loan_id:)
      loan = user.loans.find_by(id: loan_id)
      raise NotFoundError, "Loan not found" unless loan

      loan.destroy!
      nil
    end

    # Adds a new {InterestRatePeriod} to a floating-rate loan, or updates an
    # existing one when +params[:id]+ (or +params["id"]+) is present.
    #
    # Returns the full loan detail hash (same shape as {.show}) so the caller
    # receives the recalculated amortisation schedule immediately.
    #
    # @param user [User] the authenticated user who owns the loan
    # @param loan_id [Integer] the ID of the loan to modify
    # @param params [Hash] rate period attributes; may include +:id+ to update
    #   an existing period
    # @return [Hash] updated loan detail including +:amortisation_schedule+
    # @raise [Loans::LoanManager::NotFoundError] when the loan does not exist or
    #   belongs to a different user
    # @raise [Loans::LoanManager::ValidationError] when the loan is fixed-rate or
    #   when the rate period params fail validation
    def self.add_or_update_rate_period(user:, loan_id:, params:)
      loan = user.loans.find_by(id: loan_id)
      raise NotFoundError, "Loan not found" unless loan

      if loan.interest_rate_type == "fixed"
        raise ValidationError.new(
          "invalid_operation",
          details: { "base" => ["Cannot add interest rate periods to a fixed-rate loan"] }
        )
      end

      period_id = params[:id] || params["id"]

      period = if period_id
        loan.interest_rate_periods.find_by(id: period_id)
      else
        loan.interest_rate_periods.build
      end

      raise NotFoundError, "Interest rate period not found" if period.nil?

      period_attrs = params.except(:id, "id")
      period.assign_attributes(period_attrs)

      unless period.save
        raise ValidationError.new(
          period.errors.full_messages.first || "Validation failed",
          details: period.errors.as_json.transform_keys(&:to_s)
        )
      end

      show(user: user, loan_id: loan_id)
    end

    # Creates and persists a new {Loan} associated with the given user.
    #
    # For floating-rate loans, +params+ may include an +:interest_rate_periods+
    # key containing an array of hashes (each with +:start_date+ and
    # +:annual_interest_rate+, and optionally +:end_date+). These nested records
    # are built before the loan is saved so that the model's
    # +floating_rate_requires_at_least_one_period+ validation can pass.
    #
    # @param user [User] the authenticated user who owns the loan
    # @param params [Hash] loan attributes; may include +:interest_rate_periods+
    # @return [Loan] the newly persisted loan (with rate periods loaded)
    # @raise [Loans::LoanManager::ValidationError] when any model validation fails
    def self.create(user:, params:)
      loan_params   = params.except(:interest_rate_periods, "interest_rate_periods")
      period_params = params[:interest_rate_periods] || params["interest_rate_periods"] || []

      loan = user.loans.build(loan_params)

      period_params.each do |period|
        loan.interest_rate_periods.build(period)
      end

      unless loan.save
        raise ValidationError.new(
          loan.errors.full_messages.first || "Validation failed",
          details: loan.errors.as_json.transform_keys(&:to_s)
        )
      end

      loan
    end
  end
end
