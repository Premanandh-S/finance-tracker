# frozen_string_literal: true

module Loans
  # Computes amortisation schedules, next payment dates, payoff dates, and
  # dashboard summaries for loan records.
  #
  # All monetary values are integers in the smallest currency unit (e.g. paise).
  # Interest is rounded half-up per period: `floor((balance × rate / 100) / 12 + 0.5)`.
  #
  # @example Generate a schedule for a fixed-rate loan
  #   schedule = Loans::PaymentCalculator.amortisation_schedule(loan)
  #   schedule.first
  #   # => { period: 1, payment_date: #<Date>, payment_amount: 25000,
  #   #      principal: 5000, interest: 20000, remaining_balance: 245000 }
  module PaymentCalculator
    # Raised when the monthly payment is less than or equal to the interest for
    # any period, meaning the loan principal would never decrease and the loan
    # would never be paid off.
    class NonConvergingLoanError < StandardError; end

    # Maximum number of periods generated before the schedule is forcibly
    # terminated as a safety guard against near-infinite loops.
    MAX_PERIODS = 600

    # Computes the full amortisation schedule for a loan.
    #
    # For fixed-rate loans the same +annual_interest_rate+ is applied to every
    # period. For floating-rate loans the applicable +InterestRatePeriod+ is
    # resolved for each payment date: the period whose +start_date <= payment_date+
    # and (+end_date >= payment_date+ OR +end_date IS NULL+) is used. When the
    # payment date is beyond all defined periods the most recent period's rate
    # (highest +start_date+) is applied.
    #
    # Each entry in the returned array is a plain Hash:
    #   {
    #     period:            Integer,  # 1-based
    #     payment_date:      Date,
    #     payment_amount:    Integer,  # smallest currency unit
    #     principal:         Integer,
    #     interest:          Integer,
    #     remaining_balance: Integer
    #   }
    #
    # @param loan [Loan] the loan record to schedule
    # @return [Array<Hash>] ordered list of payment entries
    # @raise [Loans::PaymentCalculator::NonConvergingLoanError] when
    #   +monthly_payment <= interest+ for any period
    def self.amortisation_schedule(loan)
      schedule       = []
      balance        = loan.outstanding_balance.to_i
      monthly_pmt    = loan.monthly_payment.to_i
      payment_date   = next_payment_date(loan)
      floating       = loan.interest_rate_type == "floating"

      # Pre-load rate periods once for floating-rate loans to avoid N+1 queries.
      rate_periods = floating ? loan.interest_rate_periods.to_a : nil

      MAX_PERIODS.times do |i|
        period = i + 1
        rate   = floating ? rate_for_period(rate_periods, payment_date) : loan.annual_interest_rate.to_f

        interest = ((balance * rate / 100.0) / 12.0 + 0.5).floor

        raise NonConvergingLoanError,
              "Monthly payment (#{monthly_pmt}) is less than or equal to the " \
              "interest (#{interest}) for period #{period}. " \
              "The loan would never be paid off." if monthly_pmt <= interest

        principal = monthly_pmt - interest

        if balance - principal <= 0
          # Final period: pay exactly what remains
          payment_amount    = balance + interest
          principal         = balance
          remaining_balance = 0

          schedule << build_entry(period, payment_date, payment_amount, principal, interest, remaining_balance)
          break
        end

        remaining_balance = balance - principal

        schedule << build_entry(period, payment_date, monthly_pmt, principal, interest, remaining_balance)

        balance      = remaining_balance
        payment_date = payment_date >> 1
      end

      schedule
    end

    # Returns the next payment due date for a loan relative to a reference date.
    #
    # - If +as_of.day < loan.payment_due_day+, the due date falls in the same
    #   calendar month as +as_of+.
    # - Otherwise the due date falls in the following calendar month.
    #
    # @param loan [Loan] the loan whose +payment_due_day+ is used
    # @param as_of [Date] reference date (defaults to today)
    # @return [Date] the next payment due date
    def self.next_payment_date(loan, as_of: Date.today)
      due_day = loan.payment_due_day

      if as_of.day < due_day
        Date.new(as_of.year, as_of.month, due_day)
      else
        next_month = as_of >> 1
        Date.new(next_month.year, next_month.month, due_day)
      end
    end

    # Returns the projected payoff date for a loan (the payment_date of the
    # final schedule entry), or +nil+ if the schedule is empty.
    #
    # @param loan [Loan] the loan to evaluate
    # @return [Date, nil]
    def self.payoff_date(loan)
      schedule = amortisation_schedule(loan)
      schedule.last&.fetch(:payment_date)
    end

    # Builds a dashboard summary hash for all loans belonging to a user.
    #
    # @param user [User] the account holder
    # @return [Hash] with keys +:total_count+, +:total_outstanding_balance+,
    #   +:items+ (Array of Hashes with +:id+, +:institution_name+,
    #   +:loan_identifier+, +:outstanding_balance+, +:next_payment_date+),
    #   and +:pending_payments+ (Array of loans due in the current calendar month)
    def self.dashboard_summary(user)
      loans = user.loans.to_a

      items = loans.map do |loan|
        {
          id:                  loan.id,
          institution_name:    loan.institution_name,
          loan_identifier:     loan.loan_identifier,
          outstanding_balance: loan.outstanding_balance,
          next_payment_date:   next_payment_date(loan)
        }
      end

      pending = loans
        .select { |loan| within_current_month?(next_payment_date(loan)) }
        .map do |loan|
          {
            id:                  loan.id,
            institution_name:    loan.institution_name,
            loan_identifier:     loan.loan_identifier,
            outstanding_balance: loan.outstanding_balance,
            monthly_payment:     loan.monthly_payment,
            next_payment_date:   next_payment_date(loan)
          }
        end

      {
        total_count:               loans.size,
        total_outstanding_balance: loans.sum(&:outstanding_balance),
        items:                     items,
        pending_payments:          pending
      }
    end

    # ---------------------------------------------------------------------------
    # Private helpers
    # ---------------------------------------------------------------------------

    # Returns true when +date+ falls within the current calendar month.
    # Uses +Date.current+ for time-zone safety and +freeze_time+ compatibility.
    #
    # @param date [Date] the date to check
    # @return [Boolean]
    def self.within_current_month?(date)
      return false if date.nil?

      date.year == Date.current.year && date.month == Date.current.month
    end
    private_class_method :within_current_month?

    # Constructs a single schedule entry hash.
    #
    # @param period [Integer]
    # @param payment_date [Date]
    # @param payment_amount [Integer]
    # @param principal [Integer]
    # @param interest [Integer]
    # @param remaining_balance [Integer]
    # @return [Hash]
    def self.build_entry(period, payment_date, payment_amount, principal, interest, remaining_balance)
      {
        period:            period,
        payment_date:      payment_date,
        payment_amount:    payment_amount,
        principal:         principal,
        interest:          interest,
        remaining_balance: remaining_balance
      }
    end
    private_class_method :build_entry

    # Resolves the applicable annual interest rate for a floating-rate loan on
    # a given +payment_date+ by searching the pre-loaded +rate_periods+ array.
    #
    # Lookup rules (in priority order):
    # 1. Find the period where +start_date <= payment_date+ AND
    #    (+end_date >= payment_date+ OR +end_date IS NULL+).
    # 2. If no period covers the date (payment_date is beyond all defined
    #    periods), fall back to the period with the highest +start_date+.
    #
    # @param rate_periods [Array<InterestRatePeriod>] pre-loaded periods
    # @param payment_date [Date] the payment date to resolve a rate for
    # @return [Float] the applicable annual interest rate as a percentage
    def self.rate_for_period(rate_periods, payment_date)
      covering = rate_periods.find do |rp|
        rp.start_date <= payment_date &&
          (rp.end_date.nil? || rp.end_date >= payment_date)
      end

      return covering.annual_interest_rate.to_f if covering

      # Fall back to the most recent period (highest start_date).
      fallback = rate_periods.max_by(&:start_date)
      fallback.annual_interest_rate.to_f
    end
    private_class_method :rate_for_period
  end
end
