class ApiKey < ApplicationRecord
  # The plaintext key, set only on the instance that generated it; it is never stored.
  attr_reader :token

  belongs_to :organization
  belongs_to :user

  before_validation :generate_key, on: :create
  validates :name, presence: true
  validates :prefix, presence: true
  validates :digest, presence: true, uniqueness: true
  validate :user_belongs_to_same_organization

  # Keys are looked up by the digest of the full token (unique index), so a valid secret paired with
  # another key's prefix matches nothing. The prefix is only for display and search.
  def self.find_by_token(token)
    return if token.blank?

    find_by(digest: digest_for(token))
  end

  def self.digest_for(token)
    Digest::SHA256.hexdigest(token)
  end

  private

  # Random-only prefix, so a key reveals nothing about the organization it belongs to.
  def generate_key
    self.prefix = "pk_#{SecureRandom.alphanumeric(8).downcase}"
    @token = "#{prefix}.#{SecureRandom.urlsafe_base64(24)}"
    self.digest = self.class.digest_for(@token)
  end

  def user_belongs_to_same_organization
    return if user.nil?
    # organization&.id, not organization_id: the column is only synced from an assigned organization on save
    return if user.organization_id == organization&.id

    errors.add(:user, "must belong to the same organization")
  end
end
