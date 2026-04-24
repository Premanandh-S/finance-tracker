# frozen_string_literal: true

module Insurance
  # Orchestrates CRUD operations for {InsurancePolicy} records and their
  # associated {InsuredMember} records.
  #
  # This is a PORO module with class methods only — it holds no state.
  # All persistence is delegated to the {InsurancePolicy} and {InsuredMember} models.
  module InsuranceManager
    # Raised when a requested insurance policy does not exist or does not
    # belong to the requesting user. The message intentionally does not
    # distinguish between "not found" and "forbidden" to avoid leaking
    # resource existence.
    class NotFoundError < StandardError; end

    # Raised when insurance policy or insured member params fail model validations.
    class ValidationError < StandardError
      # @return [Hash] field-level error details
      attr_reader :details

      # @param message [String] human-readable summary
      # @param details [Hash] field-level errors keyed by attribute name
      def initialize(message = "Validation failed", details: {})
        super(message)
        @details = details
      end
    end

    # Creates and persists a new {InsurancePolicy} associated with the given user.
    # Optionally creates nested {InsuredMember} records when +params[:insured_members]+
    # is provided.
    #
    # @param user [User] the authenticated user who owns the policy
    # @param params [Hash] insurance policy attributes; may include an
    #   +:insured_members+ key with an array of member attribute hashes
    # @return [InsurancePolicy] the newly persisted policy
    # @raise [Insurance::InsuranceManager::ValidationError] when any model validation fails
    def self.create(user:, params:)
      params = params.dup
      member_params = Array(params.delete(:insured_members))
      policy = InsurancePolicy.new(params.merge(user: user))

      member_params.each do |mp|
        policy.insured_members.build(mp)
      end

      unless policy.save
        raise ValidationError.new(
          policy.errors.full_messages.first || "Validation failed",
          details: policy.errors.group_by_attribute.transform_values { |e| e.map(&:message) }
        )
      end

      policy
    end

    # Returns all insurance policies for the given user as an array of hashes.
    #
    # @param user [User] the authenticated user whose policies are listed
    # @return [Array<Hash>] one hash per policy with list fields.
    #   Returns an empty array when the user has no policies.
    def self.list(user:)
      InsurancePolicy.for_user(user).map do |policy|
        policy_list_hash(policy)
      end
    end

    # Returns full detail for a single insurance policy belonging to the given user,
    # including the associated insured members.
    #
    # @param user [User] the authenticated user requesting the policy
    # @param policy_id [Integer] the ID of the policy to retrieve
    # @return [Hash] full policy detail including +:insured_members+
    # @raise [Insurance::InsuranceManager::NotFoundError] when the policy does not exist or
    #   belongs to a different user
    def self.show(user:, policy_id:)
      policy = InsurancePolicy.for_user(user).find_by(id: policy_id)
      raise NotFoundError, "Insurance policy not found" unless policy

      policy_detail_hash(policy)
    end

    # Updates an existing {InsurancePolicy} belonging to the given user.
    #
    # @param user [User] the authenticated user who owns the policy
    # @param policy_id [Integer] the ID of the policy to update
    # @param params [Hash] insurance policy attributes to update
    # @return [InsurancePolicy] the updated policy record
    # @raise [Insurance::InsuranceManager::NotFoundError] when the policy does not exist or
    #   belongs to a different user
    # @raise [Insurance::InsuranceManager::ValidationError] when any model validation fails
    def self.update(user:, policy_id:, params:)
      policy = InsurancePolicy.for_user(user).find_by(id: policy_id)
      raise NotFoundError, "Insurance policy not found" unless policy

      policy.assign_attributes(params)

      unless policy.save
        raise ValidationError.new(
          policy.errors.full_messages.first || "Validation failed",
          details: policy.errors.group_by_attribute.transform_values { |e| e.map(&:message) }
        )
      end

      policy
    end

    # Permanently deletes an {InsurancePolicy} belonging to the given user.
    # Associated {InsuredMember} records are destroyed via +dependent: :destroy+.
    #
    # @param user [User] the authenticated user who owns the policy
    # @param policy_id [Integer] the ID of the policy to delete
    # @return [nil]
    # @raise [Insurance::InsuranceManager::NotFoundError] when the policy does not exist or
    #   belongs to a different user
    def self.destroy(user:, policy_id:)
      policy = InsurancePolicy.for_user(user).find_by(id: policy_id)
      raise NotFoundError, "Insurance policy not found" unless policy

      policy.destroy!
      nil
    end

    # Adds a new {InsuredMember} to a policy, or updates an existing one when
    # +params[:id]+ is present.
    #
    # @param user [User] the authenticated user who owns the policy
    # @param policy_id [Integer] the ID of the policy to modify
    # @param params [Hash] insured member attributes; include +:id+ to update an existing member
    # @return [Hash] the updated full policy detail hash
    # @raise [Insurance::InsuranceManager::NotFoundError] when the policy or member is not found
    # @raise [Insurance::InsuranceManager::ValidationError] when member params fail validation
    def self.add_or_update_member(user:, policy_id:, params:)
      policy = InsurancePolicy.for_user(user).find_by(id: policy_id)
      raise NotFoundError, "Insurance policy not found" unless policy

      member_id = params[:id]

      member = if member_id.present?
        found = policy.insured_members.find_by(id: member_id)
        raise NotFoundError, "Insured member not found" unless found
        found
      else
        policy.insured_members.build
      end

      member.assign_attributes(params.except(:id))

      unless member.save
        raise ValidationError.new(
          member.errors.full_messages.first || "Validation failed",
          details: member.errors.group_by_attribute.transform_values { |e| e.map(&:message) }
        )
      end

      policy_detail_hash(policy.reload)
    end

    # Removes an {InsuredMember} from a policy.
    #
    # @param user [User] the authenticated user who owns the policy
    # @param policy_id [Integer] the ID of the policy
    # @param member_id [Integer] the ID of the insured member to remove
    # @return [Hash] the updated full policy detail hash
    # @raise [Insurance::InsuranceManager::NotFoundError] when the policy or member is not found
    def self.remove_member(user:, policy_id:, member_id:)
      policy = InsurancePolicy.for_user(user).find_by(id: policy_id)
      raise NotFoundError, "Insurance policy not found" unless policy

      member = policy.insured_members.find_by(id: member_id)
      raise NotFoundError, "Insured member not found" unless member

      member.destroy!
      policy_detail_hash(policy.reload)
    end

    # Returns a dashboard summary of insurance policies for the given user.
    #
    # @param user [User] the authenticated user
    # @return [Hash] summary with +:total_count+, +:items+, and +:expiring_soon+
    #   (policies whose +renewal_date+ falls within the current or next calendar month)
    def self.dashboard_summary(user)
      policies = InsurancePolicy.for_user(user).to_a

      {
        total_count: policies.size,
        items:       policies.map do |p|
          {
            id:               p.id,
            institution_name: p.institution_name,
            policy_number:    p.policy_number,
            policy_type:      p.policy_type,
            sum_assured:      p.sum_assured,
            renewal_date:     p.renewal_date
          }
        end,
        expiring_soon: policies
          .select { |p| within_two_months?(p.renewal_date) }
          .map do |p|
            {
              id:               p.id,
              institution_name: p.institution_name,
              policy_number:    p.policy_number,
              policy_type:      p.policy_type,
              renewal_date:     p.renewal_date
            }
          end
      }
    end

    # ---------------------------------------------------------------------------
    # Private helpers
    # ---------------------------------------------------------------------------

    # Returns true when +date+ falls within the current calendar month or the
    # next calendar month. Uses +Date.current+ for time-zone safety and
    # +freeze_time+ compatibility.
    #
    # @param date [Date] the date to check
    # @return [Boolean]
    def self.within_two_months?(date)
      return false if date.nil?

      current = Date.current
      next_month = current >> 1

      (date.year == current.year && date.month == current.month) ||
        (date.year == next_month.year && date.month == next_month.month)
    end
    private_class_method :within_two_months?

    # Builds the list-item hash for a policy (no insured_members).
    # @param policy [InsurancePolicy]
    # @return [Hash]
    def self.policy_list_hash(policy)
      {
        id:                policy.id,
        institution_name:  policy.institution_name,
        policy_number:     policy.policy_number,
        policy_type:       policy.policy_type,
        sum_assured:       policy.sum_assured,
        premium_amount:    policy.premium_amount,
        premium_frequency: policy.premium_frequency,
        renewal_date:      policy.renewal_date
      }
    end
    private_class_method :policy_list_hash

    # Builds the full detail hash for a policy, including insured_members.
    # @param policy [InsurancePolicy]
    # @return [Hash]
    def self.policy_detail_hash(policy)
      policy_list_hash(policy).merge(
        policy_start_date: policy.policy_start_date,
        notes:             policy.notes,
        insured_members:   policy.insured_members.map do |m|
          { id: m.id, name: m.name, member_identifier: m.member_identifier }
        end
      )
    end
    private_class_method :policy_detail_hash
  end
end
