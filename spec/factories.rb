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
end
