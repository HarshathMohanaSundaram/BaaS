class Organization < ApplicationRecord
  has_many :users

  #enum for currency_type
  enum currency_type: { INR: 1, USD: 2, EUR: 3 }

  # Validations for presence and uniqueness
  validates :name, presence: true, uniqueness: true
  validates :currency_type, presence: true
end
