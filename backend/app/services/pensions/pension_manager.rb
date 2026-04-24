# frozen_string_literal: true

module Pensions
  # Orchestrates CRUD operations for {PensionInstrument} records and their
  # associated {PensionContribution} records.
  #
  # This is a PORO module with class methods only — it holds no state.
  # All persistence is delegated to the {PensionInstrument} and {PensionContribution} models.
  # The total corpus is always computed at query time from the sum of contribution amounts;
  # it is never stored as a column.
  #
  # @example Create a pension instrument
  #   instrument = Pensions::PensionManager.create(user: current_user, params: {
  #     institution_name:              "EPFO",
  #     pension_identifier:            "EPF-2024-001",
  #     pension_type:                  "epf",
  #     monthly_contribution_amount:   180_000,
  #     contribution_start_date:       "2020-04-01",
  #     maturity_date:                 "2045-04-01"
  #   })
  module PensionManager
    # Raised when a requested pension instrument or contribution does not exist or does not
    # belong to the requesting user. The message intentionally does not distinguish between
    # "not found" and "forbidden" to avoid leaking resource existence.
    class NotFoundError < StandardError; end

    # Raised when pension instrument or contribution params fail model validations.
    #
    # @example Rescue and inspect field details
    #   rescue Pensions::PensionManager::ValidationError => e
    #     e.message  # => "Monthly contribution amount must be greater than 0"
    #     e.details  # => { "monthly_contribution_amount" => ["must be greater than 0"] }
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

    # Creates and persists a new {PensionInstrument} associated with the given user.
    #
    # @param user [User] the authenticated user who owns the instrument
    # @param params [Hash] pension instrument attributes
    # @return [PensionInstrument] the newly persisted instrument
    # @raise [Pensions::PensionManager::ValidationError] when any model validation fails
    def self.create(user:, params:)
      instrument = PensionInstrument.new(params.merge(user: user))

      unless instrument.save
        raise ValidationError.new(
          instrument.errors.full_messages.first || "Validation failed",
          details: instrument.errors.group_by_attribute.transform_values { |e| e.map(&:message) }
        )
      end

      instrument
    end

    # Returns all pension instruments for the given user, each decorated with
    # a computed +total_corpus+.
    #
    # @param user [User] the authenticated user whose instruments are listed
    # @return [Array<Hash>] one hash per instrument; includes all list fields plus
    #   +:total_corpus+. Returns an empty array when the user has no instruments.
    def self.list(user:)
      PensionInstrument.for_user(user).map do |instrument|
        instrument_list_hash(instrument)
      end
    end

    # Returns full detail for a single pension instrument belonging to the given user,
    # including the computed total_corpus and contributions ordered by date descending.
    #
    # @param user [User] the authenticated user requesting the instrument
    # @param instrument_id [Integer] the ID of the instrument to retrieve
    # @return [Hash] full instrument detail including +:total_corpus+ and +:contributions+
    # @raise [Pensions::PensionManager::NotFoundError] when the instrument does not exist or
    #   belongs to a different user
    def self.show(user:, instrument_id:)
      instrument = PensionInstrument.for_user(user).find_by(id: instrument_id)
      raise NotFoundError, "Pension instrument not found" unless instrument

      instrument_detail_hash(instrument)
    end

    # Updates an existing {PensionInstrument} belonging to the given user.
    #
    # @param user [User] the authenticated user who owns the instrument
    # @param instrument_id [Integer] the ID of the instrument to update
    # @param params [Hash] pension instrument attributes to update
    # @return [PensionInstrument] the updated instrument record
    # @raise [Pensions::PensionManager::NotFoundError] when the instrument does not exist or
    #   belongs to a different user
    # @raise [Pensions::PensionManager::ValidationError] when any model validation fails
    def self.update(user:, instrument_id:, params:)
      instrument = PensionInstrument.for_user(user).find_by(id: instrument_id)
      raise NotFoundError, "Pension instrument not found" unless instrument

      instrument.assign_attributes(params)

      unless instrument.save
        raise ValidationError.new(
          instrument.errors.full_messages.first || "Validation failed",
          details: instrument.errors.group_by_attribute.transform_values { |e| e.map(&:message) }
        )
      end

      instrument
    end

    # Permanently deletes a {PensionInstrument} belonging to the given user.
    # Associated {PensionContribution} records are destroyed via +dependent: :destroy+.
    #
    # @param user [User] the authenticated user who owns the instrument
    # @param instrument_id [Integer] the ID of the instrument to delete
    # @return [nil]
    # @raise [Pensions::PensionManager::NotFoundError] when the instrument does not exist or
    #   belongs to a different user
    def self.destroy(user:, instrument_id:)
      instrument = PensionInstrument.for_user(user).find_by(id: instrument_id)
      raise NotFoundError, "Pension instrument not found" unless instrument

      instrument.destroy!
      nil
    end

    # Adds a new {PensionContribution} to a pension instrument.
    #
    # @param user [User] the authenticated user who owns the instrument
    # @param instrument_id [Integer] the ID of the instrument to add a contribution to
    # @param params [Hash] pension contribution attributes
    # @return [Hash] the updated full instrument detail hash
    # @raise [Pensions::PensionManager::NotFoundError] when the instrument does not exist or
    #   belongs to a different user
    # @raise [Pensions::PensionManager::ValidationError] when contribution params fail validation
    def self.add_contribution(user:, instrument_id:, params:)
      instrument = PensionInstrument.for_user(user).find_by(id: instrument_id)
      raise NotFoundError, "Pension instrument not found" unless instrument

      contribution = instrument.pension_contributions.build(params)

      unless contribution.save
        raise ValidationError.new(
          contribution.errors.full_messages.first || "Validation failed",
          details: contribution.errors.group_by_attribute.transform_values { |e| e.map(&:message) }
        )
      end

      instrument_detail_hash(instrument.reload)
    end

    # Updates an existing {PensionContribution} belonging to the given instrument.
    #
    # @param user [User] the authenticated user who owns the instrument
    # @param instrument_id [Integer] the ID of the instrument
    # @param contribution_id [Integer] the ID of the contribution to update
    # @param params [Hash] pension contribution attributes to update
    # @return [Hash] the updated full instrument detail hash
    # @raise [Pensions::PensionManager::NotFoundError] when the instrument or contribution is not found
    # @raise [Pensions::PensionManager::ValidationError] when updated params fail validation
    def self.update_contribution(user:, instrument_id:, contribution_id:, params:)
      instrument = PensionInstrument.for_user(user).find_by(id: instrument_id)
      raise NotFoundError, "Pension instrument not found" unless instrument

      contribution = instrument.pension_contributions.find_by(id: contribution_id)
      raise NotFoundError, "Pension contribution not found" unless contribution

      contribution.assign_attributes(params)

      unless contribution.save
        raise ValidationError.new(
          contribution.errors.full_messages.first || "Validation failed",
          details: contribution.errors.group_by_attribute.transform_values { |e| e.map(&:message) }
        )
      end

      instrument_detail_hash(instrument.reload)
    end

    # Removes a {PensionContribution} from a pension instrument.
    #
    # @param user [User] the authenticated user who owns the instrument
    # @param instrument_id [Integer] the ID of the instrument
    # @param contribution_id [Integer] the ID of the contribution to remove
    # @return [Hash] the updated full instrument detail hash
    # @raise [Pensions::PensionManager::NotFoundError] when the instrument or contribution is not found
    def self.remove_contribution(user:, instrument_id:, contribution_id:)
      instrument = PensionInstrument.for_user(user).find_by(id: instrument_id)
      raise NotFoundError, "Pension instrument not found" unless instrument

      contribution = instrument.pension_contributions.find_by(id: contribution_id)
      raise NotFoundError, "Pension contribution not found" unless contribution

      contribution.destroy!
      instrument_detail_hash(instrument.reload)
    end

    # Returns a dashboard summary of pension instruments for the given user.
    #
    # @param user [User] the authenticated user
    # @return [Hash] summary with +:total_count+, +:total_corpus+, and +:items+
    def self.dashboard_summary(user)
      instruments = PensionInstrument.for_user(user).to_a

      {
        total_count:  instruments.size,
        total_corpus: instruments.sum { |i| i.pension_contributions.sum(:amount) },
        items:        instruments.map do |i|
          {
            id:               i.id,
            institution_name: i.institution_name,
            pension_identifier: i.pension_identifier,
            pension_type:     i.pension_type,
            total_corpus:     i.pension_contributions.sum(:amount)
          }
        end
      }
    end

    # ---------------------------------------------------------------------------
    # Private helpers
    # ---------------------------------------------------------------------------

    # Builds the list-item hash for an instrument (no contributions detail).
    # @param instrument [PensionInstrument]
    # @return [Hash]
    def self.instrument_list_hash(instrument)
      {
        id:                            instrument.id,
        institution_name:              instrument.institution_name,
        pension_identifier:            instrument.pension_identifier,
        pension_type:                  instrument.pension_type,
        monthly_contribution_amount:   instrument.monthly_contribution_amount,
        contribution_start_date:       instrument.contribution_start_date,
        maturity_date:                 instrument.maturity_date,
        total_corpus:                  instrument.pension_contributions.sum(:amount)
      }
    end
    private_class_method :instrument_list_hash

    # Builds the full detail hash for an instrument, including contributions ordered
    # by contribution_date descending.
    # @param instrument [PensionInstrument]
    # @return [Hash]
    def self.instrument_detail_hash(instrument)
      instrument_list_hash(instrument).merge(
        notes:         instrument.notes,
        contributions: instrument.pension_contributions.order(contribution_date: :desc).map do |c|
          {
            id:               c.id,
            contribution_date: c.contribution_date,
            amount:           c.amount,
            contributor_type: c.contributor_type
          }
        end
      )
    end
    private_class_method :instrument_detail_hash
  end
end
