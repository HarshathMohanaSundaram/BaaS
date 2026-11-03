class ApiKey < ApplicationRecord
  attr_accessor :api_key
  belongs_to :organization
  belongs_to :user, optional: true

  before_validation :generate_key, on: :create
  validates :name, presence: true
  validates :prefix, presence: true
  validates :digest, presence: true, uniqueness: true

  private
  def generate_key
    base_prefix = "pk_#{organization_id}"
    unique_prefix_id = SecureRandom.alphanumeric(8).downcase
    self.prefix = "#{base_prefix}_#{unique_prefix_id}"
    secret_key = SecureRandom.urlsafe_base64(24)
    self.api_key = "#{self.prefix}.#{secret_key}"
    self.digest = Digest::SHA256.hexdigest(secret_key)
  end
end
