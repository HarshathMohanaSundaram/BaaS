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

    # The previous version is archived (inactive) and shares this plan's organization.
    # Known gap: the DB doesn't enforce same-organization for previous_plan_id;
    # a composite FK on (organization_id, previous_plan_id) would close it.
    trait :with_previous_plan do
      previous_plan { association :plan, organization: organization, archived: true }
      version { previous_plan.version + 1 }
    end
  end
end
