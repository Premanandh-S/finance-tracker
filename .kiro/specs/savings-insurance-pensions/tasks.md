# Implementation Plan: Savings, Insurance, and Pensions Feature
## Overview

This plan implements the Savings, Insurance, and Pensions feature across the Rails API backend. The backend is built domain by domain: schema and models first, then services, then controllers. All monetary values are stored as integers (smallest currency unit — paise) to avoid floating-point errors.

---

## Tasks

- [x] 1. Create database schema and run migrations
  - Create migration for savings_instruments table with all required columns and constraints
  - Create migration for insurance_policies table with all required columns and constraints
  - Create migration for insured_members table with foreign key to insurance_policies
  - Create migration for pension_instruments table with all required columns and constraints
  - Create migration for pension_contributions table with foreign key to pension_instruments
  - Add has_many associations to User model for all three domains
  - Run migrations and verify schema matches design
  - _Requirements: 1.1, 8.1, 14.1_

- [x] 2. Implement Savings domain models
  - [x] 2.1 Create SavingsInstrument model with validations and associations
    - Define SavingsInstrument model with belongs_to :user
    - Add validations for all fields per design (principal_amount > 0, annual_interest_rate 0-100, savings_type inclusion, contribution_frequency inclusion)
    - Add custom validation recurring_amount_required_for_non_one_time
    - Add custom validation maturity_date_after_start_date
    - Define SAVINGS_TYPES and CONTRIBUTION_FREQUENCIES constants and for_user scope
    - _Requirements: 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8_

- [x] 3. Implement Insurance domain models
  - [x] 3.1 Create InsurancePolicy model with validations and associations
    - Define InsurancePolicy model with belongs_to :user and has_many :insured_members, dependent: :destroy
    - Add validations for all fields per design (sum_assured > 0, premium_amount > 0, policy_type inclusion, premium_frequency inclusion)
    - Add custom validation renewal_date_must_be_in_future (on create and on update when renewal_date changed)
    - Define POLICY_TYPES and PREMIUM_FREQUENCIES constants and for_user scope
    - _Requirements: 8.2, 8.3, 8.4, 8.5, 8.6_

  - [x] 3.2 Create InsuredMember model with validations and associations
    - Define InsuredMember model with belongs_to :insurance_policy
    - Add validation for name (presence)
    - Allow member_identifier to be nullable
    - _Requirements: 13.2_

- [x] 4. Implement Pension domain models
  - [x] 4.1 Create PensionInstrument model with validations and associations
    - Define PensionInstrument model with belongs_to :user and has_many :pension_contributions, dependent: :destroy
    - Add validations for all fields per design (pension_type inclusion, monthly_contribution_amount > 0 when present)
    - Add custom validation maturity_date_after_contribution_start_date
    - Define PENSION_TYPES constant and for_user scope
    - _Requirements: 14.2, 14.3, 14.4, 14.5_

  - [x] 4.2 Create PensionContribution model with validations and associations
    - Define PensionContribution model with belongs_to :pension_instrument
    - Add validations for contribution_date (presence), amount (integer > 0), contributor_type (inclusion)
    - Define CONTRIBUTOR_TYPES constant
    - _Requirements: 19.2_

- [x] 5. Implement Savings::ValueCalculator service
  - [x] 5.1 Implement maturity_value calculation
    - Create app/services/savings/value_calculator.rb with module namespace
    - Implement self.maturity_value(instrument, compounding_frequency: 4)
    - Apply compound interest formula: floor(principal * (1 + rate/100/freq)^(freq * tenure_years) + 0.5)
    - Compute tenure_years as (maturity_date - start_date).to_f / 365.25
    - Return principal_amount when no maturity_date is present
    - _Requirements: 6.1, 6.2, 6.3, 6.4_

  - [x] 5.2 Implement payment_schedule generation
    - Implement self.payment_schedule(instrument)
    - Generate one entry per contribution period from start_date until maturity_date
    - Each entry: { contribution_date:, contribution_amount: recurring_amount, running_total: }
    - Advance dates by frequency interval (monthly >> 1, quarterly >> 3, annually >> 12)
    - Return empty array when no maturity_date is present
    - Cap schedule at 600 entries as safety guard
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5_

  - [x] 5.3 Implement next_contribution_date calculation
    - Implement self.next_contribution_date(instrument, as_of: Date.today)
    - Use start_date day-of-month as anchor, same logic as loans next_payment_date
    - _Requirements: 7.2_

- [x] 6. Implement Savings::SavingsManager service
  - [x] 6.1 Create SavingsManager with create method
    - Create app/services/savings/savings_manager.rb with module namespace
    - Implement self.create(user:, params:) — validate and persist SavingsInstrument associated with user
    - Define inner error classes: NotFoundError, ValidationError
    - Raise ValidationError with field details on invalid params
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8_

  - [x] 6.2 Implement list method in SavingsManager
    - Implement self.list(user:) — return array of hashes with computed maturity_value
    - Return empty array when user has no savings instruments
    - _Requirements: 2.1, 2.2, 2.3_

  - [x] 6.3 Implement show method in SavingsManager
    - Implement self.show(user:, instrument_id:) — find instrument, verify ownership, raise NotFoundError if not found
    - Return hash with full detail including maturity_value and payment_schedule
    - _Requirements: 3.1, 3.2, 3.3_

  - [x] 6.4 Implement update method in SavingsManager
    - Implement self.update(user:, instrument_id:, params:) — find instrument, verify ownership, apply validations
    - Raise NotFoundError or ValidationError as appropriate
    - _Requirements: 4.1, 4.2, 4.3_

  - [x] 6.5 Implement destroy method in SavingsManager
    - Implement self.destroy(user:, instrument_id:) — find instrument, verify ownership, permanently delete
    - Raise NotFoundError if instrument not found or belongs to another user
    - _Requirements: 5.1, 5.2_

  - [x] 6.6 Implement dashboard_summary in SavingsManager
    - Implement self.dashboard_summary(user)
    - Return { total_count:, total_principal:, items: [...] }
    - Each item: { id:, institution_name:, savings_identifier:, savings_type:, principal_amount:, maturity_date: }
    - Return zeros and empty array when user has no savings instruments
    - _Requirements: 22.1, 22.2, 22.3_

- [x] 7. Implement Insurance::InsuranceManager service
  - [x] 7.1 Create InsuranceManager with create method
    - Create app/services/insurance/insurance_manager.rb with module namespace
    - Implement self.create(user:, params:) — validate and persist InsurancePolicy with optional nested insured_members
    - Define inner error classes: NotFoundError, ValidationError
    - Raise ValidationError with field details on invalid params
    - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5, 8.6_

  - [x] 7.2 Implement list method in InsuranceManager
    - Implement self.list(user:) — return array of hashes with all required list fields
    - Return empty array when user has no insurance policies
    - _Requirements: 9.1, 9.2, 9.3_

  - [x] 7.3 Implement show method in InsuranceManager
    - Implement self.show(user:, policy_id:) — find policy, verify ownership, raise NotFoundError if not found
    - Return hash with full detail including insured_members array
    - _Requirements: 10.1, 10.2, 10.3_

  - [x] 7.4 Implement update method in InsuranceManager
    - Implement self.update(user:, policy_id:, params:) — find policy, verify ownership, apply validations
    - Raise NotFoundError or ValidationError as appropriate
    - _Requirements: 11.1, 11.2, 11.3_

  - [x] 7.5 Implement destroy method in InsuranceManager
    - Implement self.destroy(user:, policy_id:) — find policy, verify ownership, permanently delete (cascade via dependent: :destroy)
    - Raise NotFoundError if policy not found or belongs to another user
    - _Requirements: 12.1, 12.2_

  - [x] 7.6 Implement add_or_update_member method in InsuranceManager
    - Implement self.add_or_update_member(user:, policy_id:, params:)
    - Create or update InsuredMember, return updated policy detail
    - Raise NotFoundError if policy not found or belongs to another user
    - Raise ValidationError if member params fail validation
    - _Requirements: 13.1, 13.2, 13.3, 13.5_

  - [x] 7.7 Implement remove_member method in InsuranceManager
    - Implement self.remove_member(user:, policy_id:, member_id:)
    - Find and destroy InsuredMember, return updated policy detail
    - Raise NotFoundError if policy or member not found or policy belongs to another user
    - _Requirements: 13.4, 13.5_

  - [x] 7.8 Implement dashboard_summary in InsuranceManager
    - Implement self.dashboard_summary(user)
    - Return { total_count:, items: [...] }
    - Each item: { id:, institution_name:, policy_number:, policy_type:, sum_assured:, renewal_date: }
    - Return zero count and empty array when user has no insurance policies
    - _Requirements: 23.1, 23.2, 23.3_

- [x] 8. Implement Pensions::PensionManager service
  - [x] 8.1 Create PensionManager with create method
    - Create app/services/pensions/pension_manager.rb with module namespace
    - Implement self.create(user:, params:) — validate and persist PensionInstrument associated with user
    - Define inner error classes: NotFoundError, ValidationError
    - Raise ValidationError with field details on invalid params
    - _Requirements: 14.1, 14.2, 14.3, 14.4, 14.5_

  - [x] 8.2 Implement list method in PensionManager
    - Implement self.list(user:) — return array of hashes with computed total_corpus
    - total_corpus = sum of all associated pension_contributions amounts
    - Return empty array when user has no pension instruments
    - _Requirements: 15.1, 15.2, 15.3_

  - [x] 8.3 Implement show method in PensionManager
    - Implement self.show(user:, instrument_id:) — find instrument, verify ownership, raise NotFoundError if not found
    - Return hash with full detail including total_corpus and contributions ordered by contribution_date descending
    - _Requirements: 16.1, 16.2, 16.3_

  - [x] 8.4 Implement update method in PensionManager
    - Implement self.update(user:, instrument_id:, params:) — find instrument, verify ownership, apply validations
    - Raise NotFoundError or ValidationError as appropriate
    - _Requirements: 17.1, 17.2, 17.3_

  - [x] 8.5 Implement destroy method in PensionManager
    - Implement self.destroy(user:, instrument_id:) — find instrument, verify ownership, permanently delete (cascade via dependent: :destroy)
    - Raise NotFoundError if instrument not found or belongs to another user
    - _Requirements: 18.1, 18.2_

  - [x] 8.6 Implement add_contribution method in PensionManager
    - Implement self.add_contribution(user:, instrument_id:, params:)
    - Create PensionContribution, return updated instrument detail
    - Raise NotFoundError if instrument not found or belongs to another user
    - Raise ValidationError if contribution params fail validation
    - _Requirements: 19.1, 19.2, 19.3, 19.4_

  - [x] 8.7 Implement update_contribution method in PensionManager
    - Implement self.update_contribution(user:, instrument_id:, contribution_id:, params:)
    - Find and update PensionContribution, return updated instrument detail
    - Raise NotFoundError if instrument or contribution not found or instrument belongs to another user
    - Raise ValidationError if updated params fail validation
    - _Requirements: 20.1, 20.2, 20.3_

  - [x] 8.8 Implement remove_contribution method in PensionManager
    - Implement self.remove_contribution(user:, instrument_id:, contribution_id:)
    - Find and destroy PensionContribution, return updated instrument detail
    - Raise NotFoundError if instrument or contribution not found or instrument belongs to another user
    - _Requirements: 21.1, 21.2_

  - [x] 8.9 Implement dashboard_summary in PensionManager
    - Implement self.dashboard_summary(user)
    - Return { total_count:, total_corpus:, items: [...] }
    - Each item: { id:, institution_name:, pension_identifier:, pension_type:, total_corpus: }
    - Return zero count, zero corpus, and empty array when user has no pension instruments
    - _Requirements: 24.1, 24.2, 24.3_

- [x] 9. Implement SavingsInstrumentsController
  - Create app/controllers/savings_instruments_controller.rb
  - Add before_action :authenticate_user!
  - index: call SavingsManager.list, render JSON
  - show: call SavingsManager.show, render JSON; NotFoundError -> 404
  - create: call SavingsManager.create, render JSON 201; ValidationError -> 422
  - update: call SavingsManager.update, render JSON; NotFoundError -> 404, ValidationError -> 422
  - destroy: call SavingsManager.destroy, render 204; NotFoundError -> 404
  - Add resources :savings_instruments, only: [:index, :show, :create, :update, :destroy] to routes.rb
  - _Requirements: 1.1, 1.9, 2.1, 2.5, 3.1, 3.4, 4.1, 4.4, 5.1, 5.3_

- [x] 10. Implement InsurancePoliciesController and InsuredMembersController
  - [x] 10.1 Create InsurancePoliciesController
    - Create app/controllers/insurance_policies_controller.rb
    - Add before_action :authenticate_user!
    - index: call InsuranceManager.list, render JSON
    - show: call InsuranceManager.show, render JSON; NotFoundError -> 404
    - create: call InsuranceManager.create, render JSON 201; ValidationError -> 422
    - update: call InsuranceManager.update, render JSON; NotFoundError -> 404, ValidationError -> 422
    - destroy: call InsuranceManager.destroy, render 204; NotFoundError -> 404
    - _Requirements: 8.1, 8.7, 9.1, 9.5, 10.1, 10.4, 11.1, 11.4, 12.1, 12.3_

  - [x] 10.2 Create InsurancePolicies::InsuredMembersController
    - Create app/controllers/insurance_policies/insured_members_controller.rb
    - Add before_action :authenticate_user!
    - create: call InsuranceManager.add_or_update_member, render JSON 201
    - update: call InsuranceManager.add_or_update_member, render JSON
    - destroy: call InsuranceManager.remove_member, render JSON
    - NotFoundError -> 404, ValidationError -> 422
    - _Requirements: 13.1, 13.3, 13.4, 13.5, 13.6_

  - [x] 10.3 Add insurance routes to routes.rb
    - Add resources :insurance_policies, only: [:index, :show, :create, :update, :destroy] with nested resources :insured_members, only: [:create, :update, :destroy], module: :insurance_policies
    - _Requirements: 8.1, 9.1, 10.1, 11.1, 12.1, 13.1_

- [x] 11. Implement PensionInstrumentsController and PensionContributionsController
  - [x] 11.1 Create PensionInstrumentsController
    - Create app/controllers/pension_instruments_controller.rb
    - Add before_action :authenticate_user!
    - index: call PensionManager.list, render JSON
    - show: call PensionManager.show, render JSON; NotFoundError -> 404
    - create: call PensionManager.create, render JSON 201; ValidationError -> 422
    - update: call PensionManager.update, render JSON; NotFoundError -> 404, ValidationError -> 422
    - destroy: call PensionManager.destroy, render 204; NotFoundError -> 404
    - _Requirements: 14.1, 14.6, 15.1, 15.5, 16.1, 16.4, 17.1, 17.4, 18.1, 18.3_

  - [x] 11.2 Create PensionInstruments::PensionContributionsController
    - Create app/controllers/pension_instruments/pension_contributions_controller.rb
    - Add before_action :authenticate_user!
    - create: call PensionManager.add_contribution, render JSON 201; NotFoundError -> 404, ValidationError -> 422
    - update: call PensionManager.update_contribution, render JSON; NotFoundError -> 404, ValidationError -> 422
    - destroy: call PensionManager.remove_contribution, render JSON; NotFoundError -> 404
    - _Requirements: 19.1, 19.5, 20.1, 20.4, 21.1, 21.3_

  - [x] 11.3 Add pension routes to routes.rb
    - Add resources :pension_instruments, only: [:index, :show, :create, :update, :destroy] with nested resources :pension_contributions, only: [:create, :update, :destroy], module: :pension_instruments
    - _Requirements: 14.1, 15.1, 16.1, 17.1, 18.1, 19.1_

- [ ] 12. Write model specs
  - Write spec/models/savings_instrument_spec.rb — validations, associations, custom validations
  - Write spec/models/insurance_policy_spec.rb — validations, associations, renewal date validation
  - Write spec/models/insured_member_spec.rb — validations, associations
  - Write spec/models/pension_instrument_spec.rb — validations, associations, custom validations
  - Write spec/models/pension_contribution_spec.rb — validations, associations
  - _Requirements: 1.2-1.8, 8.2-8.6, 14.2-14.5, 19.2_

- [ ] 13. Write service specs
  - [ ] 13.1 Write spec/services/savings/value_calculator_spec.rb
    - Maturity value formula for one-time FD with known principal, rate, tenure
    - Returns principal when no maturity_date
    - Recurring schedule entry count, date intervals, running totals
    - Empty schedule when no maturity_date
    - Schedule capped at 600 entries
    - _Requirements: 6.1-6.4, 7.1-7.5_

  - [ ] 13.2 Write spec/services/savings/savings_manager_spec.rb
    - CRUD operations, auth enforcement, 404/422 cases
    - Recurring savings without recurring_amount -> ValidationError
    - Maturity date before start date -> ValidationError
    - User A accessing User B instrument -> NotFoundError
    - Dashboard summary totals and empty state
    - _Requirements: 1.1-1.9, 2.1-2.5, 3.1-3.4, 4.1-4.4, 5.1-5.3, 22.1-22.3_

  - [ ] 13.3 Write spec/services/insurance/insurance_manager_spec.rb
    - CRUD operations, auth enforcement, 404/422 cases
    - Renewal date in the past -> ValidationError
    - Member add/update/remove, policy ownership enforcement
    - Dashboard summary totals and empty state
    - _Requirements: 8.1-8.7, 9.1-9.5, 10.1-10.4, 11.1-11.4, 12.1-12.3, 13.1-13.6, 23.1-23.3_

  - [ ] 13.4 Write spec/services/pensions/pension_manager_spec.rb
    - CRUD operations, auth enforcement, 404/422 cases
    - Contribution add/update/remove, total corpus computation
    - Contributions ordered by date descending in detail response
    - Dashboard summary totals and empty state
    - _Requirements: 14.1-14.6, 15.1-15.5, 16.1-16.4, 17.1-17.4, 18.1-18.3, 19.1-19.5, 20.1-20.4, 21.1-21.3, 24.1-24.3_

- [ ] 14. Write request specs
  - Write spec/requests/savings/savings_instruments_spec.rb — auth, routing, response shapes, 404/422 cases
  - Write spec/requests/insurance/insurance_policies_spec.rb — auth, routing, response shapes, 404/422 cases
  - Write spec/requests/insurance/insured_members_spec.rb — member CRUD, policy ownership enforcement
  - Write spec/requests/pensions/pension_instruments_spec.rb — auth, routing, response shapes, 404/422 cases
  - Write spec/requests/pensions/pension_contributions_spec.rb — contribution CRUD, instrument ownership enforcement
  - _Requirements: 1.9, 2.5, 3.4, 4.4, 5.3, 8.7, 9.5, 10.4, 11.4, 12.3, 13.6, 14.6, 15.5, 16.4, 17.4, 18.3, 19.5, 20.4, 21.3_

- [ ] 15. Write property-based tests
  - [ ] 15.1 Write spec/properties/savings/savings_manager_properties_spec.rb
    - Property 1: Savings creation round-trip
    - Property 2: Invalid savings field values are rejected
    - Property 3: Recurring frequency requires recurring amount
    - Property 4: Maturity date must be after start date
    - Property 5: Savings list items contain all required fields
    - Property 6: Savings data isolation
    - _Requirements: 1.1, 1.4-1.8, 2.1, 2.2, 2.4, 25.1_

  - [ ] 15.2 Write spec/properties/savings/value_calculator_properties_spec.rb
    - Property 7: Maturity value formula correctness
    - Property 8: Recurring payment schedule correctness
    - _Requirements: 6.1, 6.2, 6.4, 7.1-7.3, 7.5_

  - [ ] 15.3 Write spec/properties/insurance/insurance_manager_properties_spec.rb
    - Property 9: Insurance creation round-trip
    - Property 10: Invalid insurance field values are rejected
    - Property 11: Insurance renewal date must be in the future
    - Property 12: Insurance data isolation
    - Property 13: Insured member add/remove round-trip
    - _Requirements: 8.1, 8.4-8.6, 9.1, 9.4, 13.1, 13.4, 25.2_

  - [ ] 15.4 Write spec/properties/pensions/pension_manager_properties_spec.rb
    - Property 14: Pension creation round-trip
    - Property 15: Pension data isolation
    - Property 16: Pension contribution round-trip
    - _Requirements: 14.1, 15.1, 15.4, 19.1, 19.2, 21.1, 25.3_

  - [x] 15.5 Write spec/properties/dashboard_properties_spec.rb
    - Property 17: Dashboard savings summary consistency
    - Property 18: Dashboard insurance summary consistency
    - Property 19: Dashboard pensions summary consistency
    - _Requirements: 22.1-22.3, 23.1-23.3, 24.1-24.3_

---

## Notes

- All monetary values are stored as integers (paise). The API accepts and returns values in paise; no conversion is performed server-side.
- The implementation follows existing project conventions: services as POROs, thin models, YARD documentation, custom errors as inner classes, frozen_string_literal: true on all Ruby files.
- total_corpus for pension instruments is always computed at query time from the sum of pension_contributions.amount — it is never stored as a column.
- The renewal_date validation for insurance policies fires on create and on update only when renewal_date is being changed, to avoid blocking updates to other fields on existing policies.
- Property tests follow the same rantly pattern established in spec/properties/auth/authentication_properties_spec.rb, with the RSpec::Core::ExampleGroup patch for property_of at the top of each file.
