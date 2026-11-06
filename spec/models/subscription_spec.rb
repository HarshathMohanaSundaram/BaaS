require 'rails_helper'

RSpec.describe Subscription, type: :model do
  describe 'validations' do
    let(:subscription) { build(:subscription) }

    it "is valid with the default factory" do
      expect(subscription).to be_valid
    end

    %i[trialing past_due canceled].each do |trait|
      it "is valid with the #{trait} factory trait" do
        expect(build(:subscription, trait)).to be_valid
      end
    end

    %i[status current_period_start current_period_end lineage_key].each do |attribute|
      it "requires #{attribute}" do
        subscription[attribute] = nil
        expect(subscription).not_to be_valid
        expect(subscription.errors[attribute]).to include("can't be blank")
      end
    end

    it "reports only the blank error for a nil lineage_key, not a plan mismatch as well" do
      subscription.lineage_key = nil
      subscription.valid?
      expect(subscription.errors[:lineage_key]).to contain_exactly("can't be blank")
    end

    %i[organization plan customer].each do |association|
      it "requires #{association}" do
        subscription.public_send("#{association}=", nil)
        expect(subscription).not_to be_valid
        expect(subscription.errors[association]).to include("must exist")
      end
    end

    describe 'status' do
      it "accepts every enum value" do
        Subscription.statuses.each_key do |status|
          subscription.status = status
          subscription.canceled_at = status == "canceled" ? Time.current : nil
          expect(subscription).to be_valid
        end
      end

      it "rejects an unknown value without raising" do
        subscription.status = :paused
        expect(subscription).not_to be_valid
        expect(subscription.errors[:status]).to include("is not included in the list")
      end
    end

    describe 'cancel_at_period_end' do
      it "defaults to false" do
        expect(Subscription.new.cancel_at_period_end).to be(false)
      end

      it "accepts true" do
        subscription.cancel_at_period_end = true
        expect(subscription).to be_valid
      end

      it "rejects nil" do
        subscription.cancel_at_period_end = nil
        expect(subscription).not_to be_valid
        expect(subscription.errors[:cancel_at_period_end]).to include("is not included in the list")
      end
    end

    describe 'canceled_at' do
      it "is required when canceled" do
        subscription.status = :canceled
        subscription.canceled_at = nil
        expect(subscription).not_to be_valid
        expect(subscription.errors[:canceled_at]).to include("can't be blank")
      end

      Subscription::LIVE_STATUSES.each do |status|
        it "must be blank when #{status}" do
          subscription.status = status
          subscription.canceled_at = Time.current
          expect(subscription).not_to be_valid
          expect(subscription.errors[:canceled_at]).to include("must be blank")
        end
      end
    end

    describe 'current_period_end' do
      it "rejects a value equal to current_period_start" do
        subscription.current_period_end = subscription.current_period_start
        expect(subscription).not_to be_valid
        expect(subscription.errors[:current_period_end]).to include(/must be greater than/)
      end

      it "rejects a value before current_period_start" do
        subscription.current_period_end = subscription.current_period_start - 1.day
        expect(subscription).not_to be_valid
        expect(subscription.errors[:current_period_end]).to include(/must be greater than/)
      end

      it "is invalid rather than raising when current_period_start is missing" do
        subscription.current_period_start = nil
        expect { subscription.valid? }.not_to raise_error
        expect(subscription).not_to be_valid
      end
    end

    describe 'lineage_key' do
      it "must match the plan's lineage key" do
        subscription.lineage_key = SecureRandom.uuid
        expect(subscription).not_to be_valid
        expect(subscription.errors[:lineage_key]).to include("must match the plan's lineage key")
      end
    end

    describe 'organization consistency' do
      it "rejects a customer from another organization" do
        subscription.customer = create(:customer)
        expect(subscription).not_to be_valid
        expect(subscription.errors[:customer]).to include("must belong to the same organization as the subscription")
      end

      it "rejects a plan from another organization" do
        other_plan = create(:plan)
        subscription.plan = other_plan
        subscription.lineage_key = other_plan.lineage_key
        expect(subscription).not_to be_valid
        expect(subscription.errors[:plan]).to include("must belong to the same organization as the subscription")
      end
    end

    describe 'plan must be live' do
      let(:organization) { create(:organization) }
      let(:plan) { create(:plan, organization: organization, archived: true) }

      it "rejects subscribing to an archived plan" do
        subscription = build(:subscription, organization: organization, plan: plan)
        expect(subscription).not_to be_valid
        expect(subscription.errors[:plan]).to include("must be live to create a subscription")
      end

      it "keeps an existing subscription valid once its plan is archived" do
        subscription = create(:subscription)
        subscription.plan.update!(archived: true)
        expect(subscription.reload).to be_valid
      end
    end

    describe 'live subscription uniqueness' do
      let!(:existing) { create(:subscription) }
      let(:duplicate_message) { "is already taken for a live subscription for this customer" }

      def same_lineage(**attributes)
        build(:subscription, organization: existing.organization, customer: existing.customer, plan: existing.plan, **attributes)
      end

      Subscription::LIVE_STATUSES.each do |status|
        it "rejects a second #{status} subscription for the same customer and lineage" do
          subscription = same_lineage(status: status)
          expect(subscription).not_to be_valid
          expect(subscription.errors[:lineage_key]).to include(duplicate_message)
        end

        it "allows a #{status} subscription when the earlier one is canceled" do
          existing.update!(status: :canceled, canceled_at: Time.current)
          expect(same_lineage(status: status)).to be_valid
        end
      end

      it "allows a canceled subscription alongside a live one" do
        expect(same_lineage(status: :canceled, canceled_at: Time.current)).to be_valid
      end

      it "allows many canceled subscriptions" do
        existing.update!(status: :canceled, canceled_at: Time.current)
        expect(same_lineage(status: :canceled, canceled_at: Time.current)).to be_valid
      end

      it "allows another customer on the same lineage" do
        customer = create(:customer, organization: existing.organization)
        expect(build(:subscription, organization: existing.organization, customer: customer, plan: existing.plan)).to be_valid
      end

      it "allows the same customer on another lineage" do
        plan = create(:plan, organization: existing.organization)
        expect(build(:subscription, organization: existing.organization, customer: existing.customer, plan: plan)).to be_valid
      end

      it "rejects a live subscription on a newer version of the same plan" do
        existing.plan.update!(archived: true)
        next_version = create(:plan, organization: existing.organization, previous_plan: existing.plan,
                                     lineage_key: existing.lineage_key, version: existing.plan.version + 1)
        subscription = same_lineage(plan: next_version)
        expect(subscription).not_to be_valid
        expect(subscription.errors[:lineage_key]).to include(duplicate_message)
      end

      it "does not treat a subscription as a duplicate of itself" do
        expect(existing).to be_valid
      end

      it "rejects reactivating a canceled subscription while another is live" do
        canceled = same_lineage(status: :canceled, canceled_at: Time.current)
        canceled.save!
        canceled.assign_attributes(status: :active, canceled_at: nil)
        expect(canceled).not_to be_valid
        expect(canceled.errors[:lineage_key]).to include(duplicate_message)
      end
    end
  end

  describe '#live?' do
    Subscription::LIVE_STATUSES.each do |status|
      it "is true when #{status}" do
        expect(build(:subscription, status: status)).to be_live
      end
    end

    it "is false when canceled" do
      expect(build(:subscription, :canceled)).not_to be_live
    end
  end

  describe 'associations' do
    let(:subscription) { create(:subscription) }

    before { subscription }

    it "is listed under its organization, plan and customer" do
      expect(subscription.organization.subscriptions).to contain_exactly(subscription)
      expect(subscription.plan.subscriptions).to contain_exactly(subscription)
      expect(subscription.customer.subscriptions).to contain_exactly(subscription)
    end

    it "stops a plan with subscriptions from being destroyed" do
      expect(subscription.plan.destroy).to be(false)
      expect(Plan.exists?(subscription.plan_id)).to be(true)
    end

    it "stops a customer with subscriptions from being destroyed" do
      expect(subscription.customer.destroy).to be(false)
      expect(Customer.exists?(subscription.customer_id)).to be(true)
    end

    it "stops an organization with subscriptions from being destroyed" do
      expect(subscription.organization.destroy).to be(false)
      expect(Organization.exists?(subscription.organization_id)).to be(true)
    end
  end

  # These bypass model validations to prove the database enforces each rule on its own.
  describe 'database constraints' do
    let(:subscription) { build(:subscription) }

    it "accepts a fully populated subscription" do
      expect { subscription.save!(validate: false) }.not_to raise_error
    end

    %i[status current_period_start current_period_end lineage_key cancel_at_period_end].each do |column|
      it "rejects a null #{column}" do
        subscription[column] = nil
        expect { subscription.save!(validate: false) }.to raise_error(ActiveRecord::NotNullViolation)
      end
    end

    %i[organization plan customer].each do |association|
      it "rejects a null #{association}_id" do
        # Clear the association, not just the column, or the loaded record repopulates it on save.
        subscription.public_send("#{association}=", nil)
        expect { subscription.save!(validate: false) }.to raise_error(ActiveRecord::NotNullViolation)
      end
    end

    describe 'check_status_enum' do
      before { subscription.save! }

      [ 0, 5 ].each do |value|
        it "rejects status #{value}" do
          # Raw SQL, since the enum would never send an unknown value to the DB.
          expect { Subscription.where(id: subscription.id).update_all(status: value) }
            .to raise_error(ActiveRecord::StatementInvalid, /check_status_enum/)
        end
      end
    end

    describe 'check_current_period_end_after_start' do
      it "rejects an end equal to the start" do
        subscription.current_period_end = subscription.current_period_start
        expect { subscription.save!(validate: false) }
          .to raise_error(ActiveRecord::StatementInvalid, /check_current_period_end_after_start/)
      end

      it "rejects an end before the start" do
        subscription.current_period_end = subscription.current_period_start - 1.second
        expect { subscription.save!(validate: false) }
          .to raise_error(ActiveRecord::StatementInvalid, /check_current_period_end_after_start/)
      end

      it "accepts an end just after the start" do
        subscription.current_period_end = subscription.current_period_start + 1.second
        expect { subscription.save!(validate: false) }.not_to raise_error
      end
    end

    describe 'check_canceled_at_status_consistency' do
      it "accepts a canceled subscription with canceled_at" do
        subscription.assign_attributes(status: :canceled, canceled_at: Time.current)
        expect { subscription.save!(validate: false) }.not_to raise_error
      end

      it "rejects a canceled subscription without canceled_at" do
        subscription.assign_attributes(status: :canceled, canceled_at: nil)
        expect { subscription.save!(validate: false) }
          .to raise_error(ActiveRecord::StatementInvalid, /check_canceled_at_status_consistency/)
      end

      Subscription::LIVE_STATUSES.each do |status|
        it "rejects a #{status} subscription with canceled_at" do
          subscription.assign_attributes(status: status, canceled_at: Time.current)
          expect { subscription.save!(validate: false) }
            .to raise_error(ActiveRecord::StatementInvalid, /check_canceled_at_status_consistency/)
        end

        it "accepts a #{status} subscription without canceled_at" do
          subscription.assign_attributes(status: status, canceled_at: nil)
          expect { subscription.save!(validate: false) }.not_to raise_error
        end
      end
    end

    describe 'organization foreign key' do
      it "rejects a nonexistent organization" do
        subscription.organization_id = -1
        expect { subscription.save!(validate: false) }.to raise_error(ActiveRecord::InvalidForeignKey)
      end

      it "prevents deleting an organization that still has subscriptions" do
        subscription.save!
        expect { subscription.organization.delete }.to raise_error(ActiveRecord::InvalidForeignKey)
      end
    end

    describe 'customer foreign key' do
      it "rejects a nonexistent customer" do
        subscription.customer_id = -1
        expect { subscription.save!(validate: false) }
          .to raise_error(ActiveRecord::InvalidForeignKey, /fk_subscriptions_customer/)
      end

      it "rejects a customer from another organization" do
        subscription.customer = create(:customer)
        expect { subscription.save!(validate: false) }
          .to raise_error(ActiveRecord::InvalidForeignKey, /fk_subscriptions_customer/)
      end

      it "prevents deleting a customer that still has subscriptions" do
        subscription.save!
        expect { subscription.customer.delete }.to raise_error(ActiveRecord::InvalidForeignKey, /fk_subscriptions_customer/)
      end

      # Only the organization_id half of the key changes here, which a single-column FK on customer_id would miss.
      it "prevents moving a customer to another organization while subscribed" do
        subscription.save!
        expect { Customer.where(id: subscription.customer_id).update_all(organization_id: create(:organization).id) }
          .to raise_error(ActiveRecord::InvalidForeignKey, /fk_subscriptions_customer/)
      end
    end

    describe 'plan foreign keys' do
      it "rejects a nonexistent plan" do
        subscription.plan_id = -1
        expect { subscription.save!(validate: false) }
          .to raise_error(ActiveRecord::InvalidForeignKey, /fk_subscriptions_plan_/)
      end

      it "rejects a plan from another organization" do
        other_plan = create(:plan)
        subscription.plan = other_plan
        subscription.lineage_key = other_plan.lineage_key
        expect { subscription.save!(validate: false) }
          .to raise_error(ActiveRecord::InvalidForeignKey, /fk_subscriptions_plan_organization/)
      end

      it "rejects a lineage_key that differs from the plan's" do
        subscription.lineage_key = SecureRandom.uuid
        expect { subscription.save!(validate: false) }
          .to raise_error(ActiveRecord::InvalidForeignKey, /fk_subscriptions_plan_lineage/)
      end

      it "prevents deleting a plan that still has subscriptions" do
        subscription.save!
        expect { subscription.plan.delete }.to raise_error(ActiveRecord::InvalidForeignKey, /fk_subscriptions_plan_/)
      end

      it "prevents moving a plan to another organization while subscribed" do
        subscription.save!
        expect { Plan.where(id: subscription.plan_id).update_all(organization_id: create(:organization).id) }
          .to raise_error(ActiveRecord::InvalidForeignKey, /fk_subscriptions_plan_organization/)
      end

      it "prevents changing a plan's lineage_key while subscribed" do
        subscription.save!
        expect { Plan.where(id: subscription.plan_id).update_all(lineage_key: SecureRandom.uuid) }
          .to raise_error(ActiveRecord::InvalidForeignKey, /fk_subscriptions_plan_lineage/)
      end
    end

    describe 'index_live_unique_subscriptions_on_customer_id_and_lineage_key' do
      let!(:existing) { create(:subscription) }

      def same_lineage(**attributes)
        build(:subscription, organization: existing.organization, customer: existing.customer, plan: existing.plan, **attributes)
      end

      Subscription::LIVE_STATUSES.each do |status|
        it "rejects a second #{status} subscription for the same customer and lineage" do
          expect { same_lineage(status: status).save!(validate: false) }
            .to raise_error(ActiveRecord::RecordNotUnique, /index_live_unique_subscriptions_on_customer_id_and_lineage_key/)
        end

        it "allows a #{status} subscription when the earlier one is canceled" do
          existing.update!(status: :canceled, canceled_at: Time.current)
          expect { same_lineage(status: status).save!(validate: false) }.not_to raise_error
        end
      end

      it "allows a canceled subscription alongside a live one" do
        expect { same_lineage(status: :canceled, canceled_at: Time.current).save!(validate: false) }.not_to raise_error
      end

      it "allows many canceled subscriptions" do
        existing.update!(status: :canceled, canceled_at: Time.current)
        expect { same_lineage(status: :canceled, canceled_at: Time.current).save!(validate: false) }.not_to raise_error
      end

      it "allows another customer on the same lineage" do
        customer = create(:customer, organization: existing.organization)
        subscription = build(:subscription, organization: existing.organization, customer: customer, plan: existing.plan)
        expect { subscription.save!(validate: false) }.not_to raise_error
      end

      it "allows the same customer on another lineage" do
        plan = create(:plan, organization: existing.organization)
        subscription = build(:subscription, organization: existing.organization, customer: existing.customer, plan: plan)
        expect { subscription.save!(validate: false) }.not_to raise_error
      end

      it "rejects reactivating a canceled subscription while another is live" do
        canceled = same_lineage(status: :canceled, canceled_at: Time.current)
        canceled.save!(validate: false)
        expect { Subscription.where(id: canceled.id).update_all(status: Subscription.statuses[:active], canceled_at: nil) }
          .to raise_error(ActiveRecord::RecordNotUnique, /index_live_unique_subscriptions_on_customer_id_and_lineage_key/)
      end
    end
  end
end
