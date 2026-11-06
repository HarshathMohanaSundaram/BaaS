FactoryBot.define do
  factory :subscription do
    # Created even under build: the plan's lineage_key comes from a DB default, and
    # organization_id must be set before the organization consistency validations compare it.
    organization { association :organization, strategy: :create }
    plan { association :plan, organization: organization, strategy: :create }
    customer { association :customer, organization: organization, strategy: :create }
    lineage_key { plan.lineage_key }
    status { :active }
    current_period_start { Time.current }
    current_period_end { 1.month.from_now }

    trait :trialing do
      status { :trialing }
      trial_ends_at { 14.days.from_now }
    end

    trait :past_due do
      status { :past_due }
    end

    trait :canceled do
      status { :canceled }
      canceled_at { Time.current }
    end
  end

  factory :api_key do
    association :organization
    user { association :user, organization: organization }
    name { "Test API Key" }
  end

  factory :customer do
    association :organization
    name { "Test Customer" }
    sequence(:email) { |n| "customer#{n}@example.com" }
    sequence(:external_id) { |n| "cus_#{n}" }
    payment_type { :credit_card }
  end

  factory :organization do
    name { "Test Organization" }
    sequence(:email) { |n| "org#{n}@example.com" }
    business_type { 0 }
    currency_type { :inr }
  end

  factory :user do
    name { "Test User" }
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "password" }
    association :organization
  end

  factory :plan do
    association :organization
    name { "Test Plan" }
    amount { 1000 }
    interval { :monthly }
    version { 1 }
    archived { false }

    trait :per_quantity do
      per_quantity { true }
      metric { "api_calls" }
    end

    # The previous version is archived (inactive) and shares this plan's organization and lineage key,
    # which the composite FKs on (previous_plan_id, organization_id) and (previous_plan_id, lineage_key) require.
    trait :with_previous_plan do
      previous_plan { association :plan, organization: organization, archived: true }
      version { previous_plan.version + 1 }
      lineage_key { previous_plan.lineage_key }
    end
  end
end
