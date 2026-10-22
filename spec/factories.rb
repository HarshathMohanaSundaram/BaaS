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
  end

  factory :plan_with_previous_plan, parent: :plan do
    # need to update the archived to false for previous plan to be inactive
    association :previous_plan, factory: :plan, archived: true
    version { plan.previous_plan.version + 1 }
  end
end
