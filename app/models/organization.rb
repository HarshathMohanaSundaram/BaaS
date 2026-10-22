class Organization < ApplicationRecord
  has_many :users
  has_many :plans


  enum :currency_type, { inr: 1, usd: 2, eur: 3 }

  # Validations for presence and uniqueness
  validates :name, presence: true
  validates :currency_type, presence: true
end
