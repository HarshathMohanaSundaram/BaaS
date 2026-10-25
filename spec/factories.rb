FactoryBot.define do
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
