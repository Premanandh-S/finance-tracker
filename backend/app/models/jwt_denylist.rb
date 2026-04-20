# frozen_string_literal: true

# Represents a revoked JWT token identified by its +jti+ (JWT ID) claim.
#
# When a user logs out, refreshes a token, or resets their password, the
# token's +jti+ is inserted here. {SessionService} checks this table before
# granting access to protected resources.
#
# Expired entries (where +exp+ is in the past) can be pruned periodically
# because a token past its +exp+ is already invalid regardless of denylist
# membership.
#
# @!attribute [rw] jti
#   @return [String] the unique JWT ID claim value (UUID v4)
# @!attribute [rw] exp
#   @return [Time] the token's expiry timestamp; used for periodic cleanup
# @!attribute [r] created_at
#   @return [Time] when this denylist entry was created
class JwtDenylist < ApplicationRecord
  self.table_name = "jwt_denylist"

  # ---------------------------------------------------------------------------
  # Validations
  # ---------------------------------------------------------------------------

  validates :jti, presence: true, uniqueness: true
  validates :exp, presence: true

  # ---------------------------------------------------------------------------
  # Scopes
  # ---------------------------------------------------------------------------

  # Finds denylist entries matching the given JWT ID.
  #
  # @param jti [String] the JWT ID to look up
  # @return [ActiveRecord::Relation<JwtDenylist>]
  scope :by_jti, ->(jti) { where(jti: jti) }

  # ---------------------------------------------------------------------------
  # Class Methods
  # ---------------------------------------------------------------------------

  # Returns whether a token with the given +jti+ has been denylisted.
  #
  # @param jti [String] the JWT ID to check
  # @return [Boolean] +true+ if a matching record exists, +false+ otherwise
  def self.denylisted?(jti)
    by_jti(jti).exists?
  end
end
