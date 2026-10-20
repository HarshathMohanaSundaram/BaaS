FactoryBot.define do
  factory :organization do
    name { "Test Organization" }
    email { "test@organization.com" }
    business_type { 0 }
    currency_type { 0 }
  end

  factory :user do
    name { "Test User" }
    email { "test@gmail.com"}
    password { "password" }
    association :organization
  end
end