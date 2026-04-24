# frozen_string_literal: true

module Savings
  # Orchestrates CRUD operations for {SavingsInstrument} records.
  #
  # This is a PORO module with class methods only — it holds no state.
  # All persistence is delegated to the {SavingsInstrument} model;
  # all computation is delegated to {Savings::ValueCalculator}.
  #
  # @example Create a fixed deposit
  #   instrument = Savings::SavingsManager.create(user: current_user, params: {
  #     institution_name:       "SBI",
  #     savings_identifier:     "FD-2024-001",
  #     savings_type:           "fd",
  #     principal_amount:       100_000_000,
  #     annual_interest_rate:   7.0,
  #     contribution_frequency: "one_time",
  #     start_date:             "2024-01-15",
  #     maturity_date:          "2026-01-15"
  #   })
  module SavingsManager
    # Raised when a requested savings instrument does not exist or does not
    # belong to the requesting user. The message intentionally does not
    # distinguish between "not found" and "forbidden" to avoid leaking
    # resource existence.
    class NotFoundError < StandardError; end

    # Raised when savings instrument params fail model validations.
    #
    # @example Rescue and inspect field details
    #   rescue Savings::SavingsManager::ValidationError => e
    #     e.message  # => "Principal amount must be greater than 0"
    #     e.details  # => { "principal_amount" => ["must be greater than 0"] }
    class ValidationError < StandardError
      # @return [Hash] field-level error details
      attr_reader :details

      # @param message [String] human-readable summary (first full message from model errors)
      # @param details [Hash] field-level errors keyed by attribute name
      def initialize(message = "Validation failed", details: {})
        super(message)
        @details = details
      end
    end

    # Creates and persists a new {SavingsInstrument} associated with the given user.
    #
    # @param user [User] the authenticated user who owns the instrument
    # @param params [Hash] savings instrument attributes
    # @return [SavingsInstrument] the newly persisted instrument
    # @raise [Savings::SavingsManager::ValidationError] when any model validation fails
    def self.create(user:, params:)
      instrument = SavingsInstrument.new(params.merge(user: user))

      unless instrument.save
        raise ValidationError.new(
          instrument.errors.full_messages.first || "Validation failed",
          details: instrument.errors.group_by_attribute.transform_values { |e| e.map(&:message) }
        )
      end

      instrument
    end

    # Returns all savings instruments for the given user, each decorated with
    # a computed +maturity_value+.
    #
    # @param user [User] the authenticated user whose instruments are listed
    # @return [Array<Hash>] one hash per instrument; includes all list fields plus
    #   +:maturity_value+. Returns an empty array when the user has no instruments.
    def self.list(user:)
      SavingsInstrument.for_user(user).map do |instrument|
        {
          id:                     instrument.id,
          institution_name:       instrument.institution_name,
          savings_identifier:     instrument.savings_identifier,
          savings_type:           instrument.savings_type,
          principal_amount:       instrument.principal_amount,
          annual_interest_rate:   instrument.annual_interest_rate,
          contribution_frequency: instrument.contribution_frequency,
          start_date:             instrument.start_date,
          maturity_date:          instrument.maturity_date,
          maturity_value:         Savings::ValueCalculator.maturity_value(instrument)
        }
      end
    end

    # Returns full detail for a single savings instrument belonging to the given user,
    # including the computed maturity value and payment schedule.
    #
    # @param user [User] the authenticated user requesting the instrument
    # @param instrument_id [Integer] the ID of the instrument to retrieve
    # @return [Hash] full instrument detail including +:maturity_value+ and +:payment_schedule+
    # @raise [Savings::SavingsManager::NotFoundError] when the instrument does not exist or
    #   belongs to a different user
    def self.show(user:, instrument_id:)
      instrument = SavingsInstrument.for_user(user).find_by(id: instrument_id)
      raise NotFoundError, "Savings instrument not found" unless instrument

      {
        id:                     instrument.id,
        institution_name:       instrument.institution_name,
        savings_identifier:     instrument.savings_identifier,
        savings_type:           instrument.savings_type,
        principal_amount:       instrument.principal_amount,
        annual_interest_rate:   instrument.annual_interest_rate,
        contribution_frequency: instrument.contribution_frequency,
        start_date:             instrument.start_date,
        maturity_date:          instrument.maturity_date,
        notes:                  instrument.notes,
        maturity_value:         Savings::ValueCalculator.maturity_value(instrument),
        payment_schedule:       Savings::ValueCalculator.payment_schedule(instrument)
      }
    end

    # Updates an existing {SavingsInstrument} belonging to the given user.
    #
    # @param user [User] the authenticated user who owns the instrument
    # @param instrument_id [Integer] the ID of the instrument to update
    # @param params [Hash] savings instrument attributes to update
    # @return [SavingsInstrument] the updated instrument record
    # @raise [Savings::SavingsManager::NotFoundError] when the instrument does not exist or
    #   belongs to a different user
    # @raise [Savings::SavingsManager::ValidationError] when any model validation fails
    def self.update(user:, instrument_id:, params:)
      instrument = SavingsInstrument.for_user(user).find_by(id: instrument_id)
      raise NotFoundError, "Savings instrument not found" unless instrument

      instrument.assign_attributes(params)

      unless instrument.save
        raise ValidationError.new(
          instrument.errors.full_messages.first || "Validation failed",
          details: instrument.errors.group_by_attribute.transform_values { |e| e.map(&:message) }
        )
      end

      instrument
    end

    # Permanently deletes a {SavingsInstrument} belonging to the given user.
    #
    # @param user [User] the authenticated user who owns the instrument
    # @param instrument_id [Integer] the ID of the instrument to delete
    # @return [nil]
    # @raise [Savings::SavingsManager::NotFoundError] when the instrument does not exist or
    #   belongs to a different user
    def self.destroy(user:, instrument_id:)
      instrument = SavingsInstrument.for_user(user).find_by(id: instrument_id)
      raise NotFoundError, "Savings instrument not found" unless instrument

      instrument.destroy!
      nil
    end

    # Returns a dashboard summary of savings instruments for the given user.
    #
    # @param user [User] the authenticated user
    # @return [Hash] summary with +:total_count+, +:total_principal+, and +:items+
    def self.dashboard_summary(user)
      instruments = SavingsInstrument.for_user(user).to_a

      {
        total_count:     instruments.size,
        total_principal: instruments.sum(&:principal_amount),
        items:           instruments.map do |i|
          {
            id:                 i.id,
            institution_name:   i.institution_name,
            savings_identifier: i.savings_identifier,
            savings_type:       i.savings_type,
            principal_amount:   i.principal_amount,
            maturity_date:      i.maturity_date
          }
        end
      }
    end
  end
end
