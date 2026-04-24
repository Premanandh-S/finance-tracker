# frozen_string_literal: true

module Savings
  # Computes projected maturity values and contribution schedules for savings instruments.
  module ValueCalculator
    # Computes the projected maturity value using compound interest.
    # Returns principal_amount when no maturity_date is present.
    #
    # Formula: floor(principal * (1 + rate/100/freq)^(freq * tenure_years) + 0.5)
    # tenure_years = (maturity_date - start_date).to_f / 365.25
    #
    # @param instrument [SavingsInstrument]
    # @param compounding_frequency [Integer] defaults to 4 (quarterly)
    # @return [Integer] maturity value in smallest currency unit (paise)
    def self.maturity_value(instrument, compounding_frequency: 4)
      return instrument.principal_amount unless instrument.maturity_date.present?

      principal = instrument.principal_amount
      rate = instrument.annual_interest_rate.to_f
      tenure_years = (instrument.maturity_date - instrument.start_date).to_f / 365.25
      freq = compounding_frequency

      raw = principal * ((1 + rate / 100.0 / freq) ** (freq * tenure_years))
      (raw + 0.5).floor
    end

    # Generates the projected contribution schedule for recurring savings instruments.
    # Returns an empty array when no maturity_date is present.
    # Capped at 600 entries as a safety guard.
    #
    # @param instrument [SavingsInstrument]
    # @return [Array<Hash>] schedule entries with contribution_date, contribution_amount, running_total
    def self.payment_schedule(instrument)
      return [] unless instrument.maturity_date.present?
      return [] if instrument.contribution_frequency == "one_time"
      return [] unless instrument.recurring_amount.present?

      entries = []
      current_date = instrument.start_date
      running_total = 0

      while current_date <= instrument.maturity_date && entries.length < 600
        running_total += instrument.recurring_amount
        entries << {
          contribution_date: current_date,
          contribution_amount: instrument.recurring_amount,
          running_total: running_total
        }
        current_date = advance_by_frequency(current_date, instrument.contribution_frequency)
      end

      entries
    end

    # Returns the next contribution date for a recurring savings instrument.
    # Uses the start_date's day-of-month as the anchor.
    #
    # @param instrument [SavingsInstrument]
    # @param as_of [Date] defaults to Date.today
    # @return [Date]
    def self.next_contribution_date(instrument, as_of: Date.today)
      due_day = instrument.start_date.day

      if as_of.day < due_day
        Date.new(as_of.year, as_of.month, due_day)
      else
        next_month = as_of >> 1
        Date.new(next_month.year, next_month.month, due_day)
      end
    end

    # Advances a date by the given contribution frequency interval.
    #
    # @param date [Date]
    # @param frequency [String] one of 'monthly', 'quarterly', 'annually'
    # @return [Date]
    def self.advance_by_frequency(date, frequency)
      case frequency
      when "monthly"   then date >> 1
      when "quarterly" then date >> 3
      when "annually"  then date >> 12
      else date >> 1
      end
    end
    private_class_method :advance_by_frequency
  end
end
