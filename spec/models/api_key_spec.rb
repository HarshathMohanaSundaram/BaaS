require 'rails_helper'

RSpec.describe ApiKey, type: :model do
  describe 'validations' do
    let(:api_key) { build(:api_key) }

    it "is valid with the default factory" do
      expect(api_key).to be_valid
    end

    it "requires a name" do
      api_key.name = nil
      expect(api_key).not_to be_valid
      expect(api_key.errors[:name]).to include("can't be blank")
    end

    it "rejects an empty name" do
      api_key.name = ""
      expect(api_key).not_to be_valid
      expect(api_key.errors[:name]).to include("can't be blank")
    end

    it "requires an organization" do
      api_key.organization = nil
      expect(api_key).not_to be_valid
      expect(api_key.errors[:organization]).to include("must exist")
    end

    it "requires a user" do
      api_key.user = nil
      expect(api_key).not_to be_valid
      expect(api_key.errors[:user]).to include("must exist")
    end

    describe 'user' do
      it "is valid with a user from the same organization" do
        api_key.user = create(:user, organization: api_key.organization)
        expect(api_key).to be_valid
      end

      it "is invalid with a user from another organization" do
        api_key.user = create(:user)
        expect(api_key).not_to be_valid
        expect(api_key.errors[:user]).to include("must belong to the same organization")
      end
    end

    # On create the key is regenerated before validation, so these are only reachable on a saved key.
    describe 'on a saved key' do
      let(:api_key) { create(:api_key) }

      it "requires a prefix" do
        api_key.prefix = nil
        expect(api_key).not_to be_valid
        expect(api_key.errors[:prefix]).to include("can't be blank")
      end

      it "requires a digest" do
        api_key.digest = nil
        expect(api_key).not_to be_valid
        expect(api_key.errors[:digest]).to include("can't be blank")
      end

      it "rejects a duplicate digest" do
        other = create(:api_key)
        api_key.digest = other.digest
        expect(api_key).not_to be_valid
        expect(api_key.errors[:digest]).to include("has already been taken")
      end
    end
  end

  describe 'key generation' do
    let(:api_key) { create(:api_key) }

    it "builds a random-only prefix" do
      expect(api_key.prefix).to match(/\Apk_[a-z0-9]{8}\z/)
    end

    it "does not expose the organization id in the prefix" do
      expect(api_key.prefix.split("_")).not_to include(api_key.organization_id.to_s)
    end

    it "exposes the plaintext token as the prefix and secret joined by a dot" do
      expect(api_key.token).to match(/\A#{api_key.prefix}\.[A-Za-z0-9_-]{32}\z/)
    end

    it "stores the SHA-256 digest of the full token, prefix included" do
      expect(api_key.digest).to eq(Digest::SHA256.hexdigest(api_key.token))
    end

    it "does not store the plaintext token" do
      expect(ApiKey.find(api_key.id).token).to be_nil
    end

    it "overwrites a prefix and digest supplied by the caller" do
      api_key = create(:api_key, prefix: "custom", digest: "custom")
      expect(api_key.prefix).not_to eq("custom")
      expect(api_key.digest).not_to eq("custom")
    end

    it "generates a different key every time" do
      other = create(:api_key, organization: api_key.organization, user: api_key.user)
      expect(other.prefix).not_to eq(api_key.prefix)
      expect(other.digest).not_to eq(api_key.digest)
    end

    it "does not regenerate the key on update" do
      expect { api_key.update!(name: "Renamed") }.not_to(change { [api_key.prefix, api_key.digest] })
    end
  end

  describe '.find_by_token' do
    let!(:api_key) { create(:api_key) }

    it "finds the key by its token" do
      expect(ApiKey.find_by_token(api_key.token)).to eq(api_key)
    end

    it "returns nil for an unknown token" do
      expect(ApiKey.find_by_token("pk_unknown1.#{SecureRandom.urlsafe_base64(24)}")).to be_nil
    end

    it "returns nil for a blank token" do
      expect(ApiKey.find_by_token(nil)).to be_nil
      expect(ApiKey.find_by_token("")).to be_nil
    end

    it "rejects a valid secret paired with another key's prefix" do
      other = create(:api_key)
      secret = api_key.token.delete_prefix("#{api_key.prefix}.")

      expect(ApiKey.find_by_token("#{other.prefix}.#{secret}")).to be_nil
    end
  end

  # These bypass model validations (and the key-generating callback) to prove the database enforces each rule on its own.
  describe 'database constraints' do
    let(:api_key) { build(:api_key, prefix: "pk_test_prefix", digest: SecureRandom.hex(32)) }

    it "accepts a fully populated key" do
      expect { api_key.save!(validate: false) }.not_to raise_error
    end

    %i[name prefix digest].each do |column|
      it "rejects a null #{column}" do
        api_key[column] = nil
        expect { api_key.save!(validate: false) }.to raise_error(ActiveRecord::NotNullViolation)
      end

      it "rejects an empty #{column}" do
        api_key[column] = ""
        expect { api_key.save!(validate: false) }
          .to raise_error(ActiveRecord::StatementInvalid, /check_api_keys_#{column}_not_empty/)
      end
    end

    it "rejects a null organization_id" do
      # Clear the association, not just the column, or the loaded organization repopulates it on save.
      api_key.organization = nil
      expect { api_key.save!(validate: false) }.to raise_error(ActiveRecord::NotNullViolation)
    end

    it "rejects a null user_id" do
      api_key.user = nil
      expect { api_key.save!(validate: false) }.to raise_error(ActiveRecord::NotNullViolation)
    end

    it "rejects a nonexistent organization" do
      api_key.organization_id = -1
      expect { api_key.save!(validate: false) }.to raise_error(ActiveRecord::InvalidForeignKey)
    end

    it "rejects a nonexistent user" do
      api_key.user_id = -1
      expect { api_key.save!(validate: false) }.to raise_error(ActiveRecord::InvalidForeignKey)
    end

    it "rejects a duplicate digest" do
      existing = create(:api_key)
      api_key.digest = existing.digest
      expect { api_key.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique, /index_api_keys_on_digest/)
    end

    it "allows a duplicate prefix" do
      existing = create(:api_key)
      api_key.prefix = existing.prefix
      expect { api_key.save!(validate: false) }.not_to raise_error
    end

    it "prevents deleting an organization that still has keys" do
      api_key.save!(validate: false)
      expect { api_key.organization.delete }.to raise_error(ActiveRecord::InvalidForeignKey)
    end

    it "prevents deleting a user that still has keys" do
      api_key.save!(validate: false)
      expect { api_key.user.delete }.to raise_error(ActiveRecord::InvalidForeignKey)
    end
  end

  describe 'indexes' do
    let(:indexes) { ApiKey.connection.indexes(:api_keys).index_by(&:name) }

    it "has a unique index on digest" do
      expect(indexes["index_api_keys_on_digest"]).to have_attributes(columns: ["digest"], unique: true)
    end

    it "has a non-unique index on prefix" do
      expect(indexes["index_api_keys_on_prefix"]).to have_attributes(columns: ["prefix"], unique: false)
    end

    it "has a non-unique index on organization_id" do
      expect(indexes["index_api_keys_on_organization_id"]).to have_attributes(columns: ["organization_id"], unique: false)
    end

    it "has a non-unique index on user_id" do
      expect(indexes["index_api_keys_on_user_id"]).to have_attributes(columns: ["user_id"], unique: false)
    end
  end
end
