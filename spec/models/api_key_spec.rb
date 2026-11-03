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

    it "does not require a user at the model level" do
      api_key.user = nil
      expect(api_key).to be_valid
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

    it "builds the prefix from the organization id and a random suffix" do
      expect(api_key.prefix).to match(/\Apk_#{api_key.organization_id}_[a-z0-9]{8}\z/)
    end

    it "exposes the plaintext key as the prefix and secret joined by a dot" do
      expect(api_key.api_key).to start_with("#{api_key.prefix}.")
    end

    it "stores the SHA-256 digest of the secret, not the secret itself" do
      secret = api_key.api_key.delete_prefix("#{api_key.prefix}.")
      expect(api_key.digest).to eq(Digest::SHA256.hexdigest(secret))
      expect(ApiKey.find(api_key.id).api_key).to be_nil
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
