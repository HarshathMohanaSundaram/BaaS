require 'rails_helper'

RSpec.describe Customer, type: :model do
  describe 'validations' do
    let(:customer) { build(:customer) }

    it "is valid with the default factory" do
      expect(customer).to be_valid
    end

    %i[name email external_id payment_type].each do |attribute|
      it "requires #{attribute}" do
        customer[attribute] = nil
        expect(customer).not_to be_valid
        expect(customer.errors[attribute]).to include("can't be blank")
      end
    end

    it "rejects an empty external_id" do
      customer.external_id = ""
      expect(customer).not_to be_valid
      expect(customer.errors[:external_id]).to include("can't be blank")
    end

    it "requires an organization" do
      customer.organization = nil
      expect(customer).not_to be_valid
      expect(customer.errors[:organization]).to include("must exist")
    end

    describe 'external_id uniqueness' do
      let!(:existing) { create(:customer) }

      it "rejects a duplicate external_id within the same organization" do
        customer = build(:customer, organization: existing.organization, external_id: existing.external_id)
        expect(customer).not_to be_valid
        expect(customer.errors[:external_id]).to include("has already been taken")
      end

      it "allows the same external_id in another organization" do
        expect(build(:customer, external_id: existing.external_id)).to be_valid
      end
    end

    describe 'account_manager' do
      it "is optional" do
        customer.account_manager = nil
        expect(customer).to be_valid
      end

      it "is valid with a user from the same organization" do
        customer.account_manager = create(:user, organization: customer.organization)
        expect(customer).to be_valid
      end

      it "is invalid with a user from another organization" do
        customer.account_manager = create(:user)
        expect(customer).not_to be_valid
        expect(customer.errors[:account_manager]).to include("must belong to the same organization")
      end

      it "does not move the customer into the manager's organization" do
        organization = customer.organization
        customer.account_manager = create(:user)
        expect(customer.organization_id).to eq(organization.id)
      end
    end

    describe 'payment_type' do
      it "defaults to credit_card" do
        expect(Customer.new.payment_type).to eq("credit_card")
      end

      it "accepts every enum value" do
        Customer.payment_types.each_key do |type|
          customer.payment_type = type
          expect(customer).to be_valid
        end
      end

      it "raises on an unknown value" do
        expect { customer.payment_type = :paypal }.to raise_error(ArgumentError, /'paypal' is not a valid payment_type/)
      end
    end
  end

  describe 'associations' do
    it "returns the account manager" do
      manager = create(:user)
      customer = create(:customer, organization: manager.organization, account_manager: manager)

      expect(Customer.find(customer.id).account_manager).to eq(manager)
    end
  end

  # These bypass model validations to prove the database enforces each rule on its own.
  describe 'database constraints' do
    let(:customer) { build(:customer) }

    it "accepts a fully populated customer" do
      expect { customer.save!(validate: false) }.not_to raise_error
    end

    %i[name email external_id payment_type].each do |column|
      it "rejects a null #{column}" do
        customer[column] = nil
        expect { customer.save!(validate: false) }.to raise_error(ActiveRecord::NotNullViolation)
      end
    end

    it "rejects a null organization_id" do
      # Clear the association, not just the column, or the loaded organization repopulates it on save.
      customer.organization = nil
      expect { customer.save!(validate: false) }.to raise_error(ActiveRecord::NotNullViolation)
    end

    it "rejects a nonexistent organization" do
      customer.organization_id = -1
      expect { customer.save!(validate: false) }.to raise_error(ActiveRecord::InvalidForeignKey)
    end

    it "rejects an empty external_id" do
      customer.external_id = ""
      expect { customer.save!(validate: false) }
        .to raise_error(ActiveRecord::StatementInvalid, /check_customers_external_id_not_empty/)
    end

    it "rejects a payment_type outside the enum" do
      customer.save!
      # Raw SQL, since assigning an unknown value through the enum raises before reaching the DB.
      expect { Customer.where(id: customer.id).update_all(payment_type: 4) }
        .to raise_error(ActiveRecord::StatementInvalid, /check_customers_payment_type_valid/)
    end

    describe 'external_id uniqueness' do
      let!(:existing) { create(:customer) }

      it "rejects a duplicate external_id within the same organization" do
        customer = build(:customer, organization: existing.organization, external_id: existing.external_id)
        expect { customer.save!(validate: false) }
          .to raise_error(ActiveRecord::RecordNotUnique, /index_customers_on_organization_and_external_id/)
      end

      it "allows the same external_id in another organization" do
        customer = build(:customer, external_id: existing.external_id)
        expect { customer.save!(validate: false) }.not_to raise_error
      end
    end

    describe 'stripe_customer_id uniqueness' do
      it "rejects a duplicate stripe_customer_id" do
        create(:customer, stripe_customer_id: "cus_stripe_1")
        customer.stripe_customer_id = "cus_stripe_1"
        expect { customer.save!(validate: false) }
          .to raise_error(ActiveRecord::RecordNotUnique, /index_customers_on_stripe_customer_id/)
      end

      it "allows many customers without a stripe_customer_id" do
        create(:customer, stripe_customer_id: nil)
        customer.stripe_customer_id = nil
        expect { customer.save!(validate: false) }.not_to raise_error
      end
    end

    describe 'account manager foreign key' do
      it "accepts a manager from the same organization" do
        customer.account_manager_id = create(:user, organization: customer.organization).id
        expect { customer.save!(validate: false) }.not_to raise_error
      end

      it "rejects a manager from another organization" do
        customer.account_manager_id = create(:user).id
        expect { customer.save!(validate: false) }
          .to raise_error(ActiveRecord::InvalidForeignKey, /fk_customers_account_manager/)
      end

      it "rejects a nonexistent manager" do
        customer.account_manager_id = -1
        expect { customer.save!(validate: false) }
          .to raise_error(ActiveRecord::InvalidForeignKey, /fk_customers_account_manager/)
      end

      it "does not check a customer without a manager" do
        customer.account_manager_id = nil
        expect { customer.save!(validate: false) }.not_to raise_error
      end

      it "prevents deleting a user who still manages customers" do
        manager = create(:user, organization: customer.organization)
        customer.update!(account_manager: manager)
        expect { manager.delete }.to raise_error(ActiveRecord::InvalidForeignKey)
      end

      # Only the organization_id half of the key changes here, which a single-column FK on account_manager_id would miss.
      describe 'composite key' do
        let(:manager) { create(:user, organization: customer.organization) }

        before { customer.update!(account_manager: manager) }

        it "rejects moving a customer to another organization while keeping its manager" do
          expect { Customer.where(id: customer.id).update_all(organization_id: create(:organization).id) }
            .to raise_error(ActiveRecord::InvalidForeignKey, /fk_customers_account_manager/)
        end

        it "allows moving a customer to another organization once the manager is cleared" do
          expect { Customer.where(id: customer.id).update_all(organization_id: create(:organization).id, account_manager_id: nil) }
            .not_to raise_error
        end

        it "prevents moving a manager to another organization while they manage customers" do
          expect { User.where(id: manager.id).update_all(organization_id: create(:organization).id) }
            .to raise_error(ActiveRecord::InvalidForeignKey, /fk_customers_account_manager/)
        end
      end
    end

    it "prevents deleting an organization that still has customers" do
      customer.save!
      expect { customer.organization.delete }.to raise_error(ActiveRecord::InvalidForeignKey)
    end
  end

  describe 'schema' do
    let(:connection) { Customer.connection }

    describe 'foreign keys' do
      let(:foreign_keys) { connection.foreign_keys(:customers).index_by(&:name) }

      it "references users on (id, organization_id) for the account manager" do
        expect(foreign_keys["fk_customers_account_manager"]).to have_attributes(
          to_table: "users",
          column: %w[account_manager_id organization_id],
          primary_key: %w[id organization_id]
        )
      end

      it "references organizations on organization_id" do
        fk = foreign_keys.values.find { |key| key.to_table == "organizations" }
        expect(fk).to have_attributes(column: "organization_id", primary_key: "id")
      end

      # Postgres only lets a foreign key reference a column set covered by a unique index.
      it "is backed by a unique index on users (organization_id, id)" do
        index = connection.indexes(:users).find { |i| i.name == "index_users_on_organization_and_id" }
        expect(index).to have_attributes(columns: %w[organization_id id], unique: true)
      end
    end

    describe 'indexes' do
      let(:indexes) { connection.indexes(:customers).index_by(&:name) }

      it "has a unique index on (organization_id, external_id)" do
        expect(indexes["index_customers_on_organization_and_external_id"])
          .to have_attributes(columns: %w[organization_id external_id], unique: true)
      end

      it "has a unique index on stripe_customer_id" do
        expect(indexes["index_customers_on_stripe_customer_id"]).to have_attributes(columns: ["stripe_customer_id"], unique: true)
      end

      it "has a non-unique index on (account_manager_id, organization_id) covering the account manager FK" do
        expect(indexes["index_customers_on_account_manager"])
          .to have_attributes(columns: %w[account_manager_id organization_id], unique: false)
      end

      # Lets other tables reference a customer with a composite FK pinned to its organization.
      it "has a unique index on (id, organization_id)" do
        expect(indexes["index_customers_on_id_and_organization_id"])
          .to have_attributes(columns: %w[id organization_id], unique: true)
      end
    end
  end
end
