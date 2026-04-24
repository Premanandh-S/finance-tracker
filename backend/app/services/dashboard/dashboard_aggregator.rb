# frozen_string_literal: true

module Dashboard
  # Assembles the full dashboard payload by delegating to each domain's
  # existing summary method.
  #
  # This is a PORO module with a single class method — it holds no state and
  # owns no query logic. Each domain manager is responsible for scoping its
  # own data to the given user.
  #
  # @example Fetch the dashboard payload for a user
  #   payload = Dashboard::DashboardAggregator.call(user: current_user)
  #   payload[:savings]   # => { total_count: ..., total_principal: ..., items: [...] }
  #   payload[:loans]     # => { total_count: ..., total_outstanding_balance: ..., items: [...], pending_payments: [...] }
  #   payload[:insurance] # => { total_count: ..., items: [...], expiring_soon: [...] }
  #   payload[:pensions]  # => { total_count: ..., total_corpus: ..., items: [...] }
  class DashboardAggregator
    # Assembles the full dashboard payload for the given user.
    #
    # Delegates to all four domain summary methods and merges the results
    # under the top-level keys +:savings+, +:loans+, +:insurance+, and
    # +:pensions+.
    #
    # @param user [User] the authenticated account holder
    # @return [Hash] with keys +:savings+, +:loans+, +:insurance+, +:pensions+
    def self.call(user:)
      {
        savings:   Savings::SavingsManager.dashboard_summary(user),
        loans:     Loans::PaymentCalculator.dashboard_summary(user),
        insurance: Insurance::InsuranceManager.dashboard_summary(user),
        pensions:  Pensions::PensionManager.dashboard_summary(user)
      }
    end
  end
end
