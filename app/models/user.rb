class User < ApplicationRecord
  has_secure_password

  belongs_to :organization
  has_many :api_keys, dependent: :destroy

  validates :email, presence: true, uniqueness: true
end
