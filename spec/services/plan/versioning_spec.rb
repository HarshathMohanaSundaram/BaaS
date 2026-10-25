require 'rails_helper'

RSpec.describe Plan::Versioning do
  let(:organization) { create(:organization) }
  let!(:plan) { create(:plan, organization: organization, name: "Starter", amount: 1000, interval: :monthly) }

  subject(:execute) { described_class.new(plan, params).execute }

  describe '#execute' do
    context 'when only the name is changed' do
      let(:params) { { name: "Starter Plus" } }

      it "updates the plan in place and returns it" do
        expect(execute).to eq(plan)
        expect(plan.reload.name).to eq("Starter Plus")
      end

      it "does not create a new version" do
        expect { execute }.not_to change(Plan, :count)
        expect(plan.reload).to have_attributes(version: 1, archived: false)
      end

      it "keeps the lineage key" do
        expect { execute }.not_to change { plan.reload.lineage_key }
      end
    end

    context 'when nothing is changed' do
      let(:params) { { name: "Starter", amount: 1000, interval: "monthly" } }

      it "returns the plan without creating a new version" do
        expect { expect(execute).to eq(plan) }.not_to change(Plan, :count)
      end

      it "compares type-cast values, so string params matching the current values are not a change" do
        expect { described_class.new(plan, { amount: "1000" }).execute }.not_to change(Plan, :count)
      end
    end

    context 'when params use string keys' do
      let(:params) { { "amount" => 2000 } }

      it "treats them the same as symbol keys" do
        expect(execute).to have_attributes(amount: 2000, version: 2)
      end
    end

    describe 'invalid params' do
      shared_examples 'rejected as invalid' do |attribute, message|
        it "raises InvalidRecordError with the error on the plan" do
          expect { execute }.to raise_error(InvalidRecordError) { |error|
            expect(error.record).to eq(plan)
            expect(error.record.errors[attribute]).to include(message)
          }
        end

        it "writes nothing" do
          expect { execute rescue nil }.not_to change(Plan, :count)
          expect(plan.reload).to have_attributes(name: "Starter", amount: 1000, version: 1, archived: false)
        end
      end

      context 'when the name is blank (an in-place change)' do
        let(:params) { { name: "" } }

        include_examples 'rejected as invalid', :name, "can't be blank"
      end

      context 'when the amount is negative (a versioned change)' do
        let(:params) { { amount: -1 } }

        include_examples 'rejected as invalid', :amount, "must be greater than or equal to 0"
      end

      context 'when per_quantity is set without a metric' do
        let(:params) { { per_quantity: true } }

        include_examples 'rejected as invalid', :metric, "can't be blank"
      end
    end

    describe 'non-editable attributes' do
      let(:other_organization) { create(:organization) }

      {
        archived: true,
        version: 5,
        previous_plan_id: 1,
        lineage_key: SecureRandom.uuid,
        id: 999
      }.each do |attribute, value|
        context "when params include #{attribute}" do
          let(:params) { { amount: 2000, attribute => value } }

          it "raises InvalidRecordError and writes nothing" do
            expect { execute }.to raise_error(InvalidRecordError) { |error|
              expect(error.record.errors[:base]).to include("#{attribute} cannot be changed")
            }
            expect(Plan.count).to eq(1)
            expect(plan.reload).to have_attributes(amount: 1000, version: 1, archived: false)
          end
        end
      end

      context 'when params include organization_id' do
        let(:params) { { organization_id: other_organization.id } }

        it "raises InvalidRecordError and leaves the plan in its organization" do
          expect { execute }.to raise_error(InvalidRecordError, /organization_id cannot be changed/)
          expect(plan.reload.organization_id).to eq(organization.id)
        end
      end

      it "lists every non-editable attribute" do
        expect { described_class.new(plan, { archived: true, version: 5 }).execute }
          .to raise_error(InvalidRecordError) { |error|
            expect(error.record.errors[:base]).to contain_exactly("archived cannot be changed", "version cannot be changed")
          }
      end
    end

    context 'when an attribute other than name is changed' do
      let(:params) { { amount: 2000 } }

      it "creates a new plan" do
        expect { execute }.to change(Plan, :count).by(1)
      end

      it "returns the new plan with the updated attributes, an incremented version and a link to the old plan" do
        new_plan = execute

        expect(new_plan).to be_persisted
        expect(new_plan).not_to eq(plan)
        expect(new_plan).to have_attributes(
          amount: 2000,
          name: "Starter",
          interval: "monthly",
          organization_id: organization.id,
          version: 2,
          previous_plan_id: plan.id,
          lineage_key: plan.lineage_key,
          archived: false
        )
      end

      it "archives the old plan and keeps its original attributes" do
        execute

        expect(plan.reload).to have_attributes(archived: true, amount: 1000, version: 1)
      end

      it "keeps the lineage key on the archived old plan" do
        expect { execute }.not_to change { plan.reload.lineage_key }
      end

      it "leaves only the new plan active" do
        new_plan = execute

        expect(Plan.active.where(organization: organization)).to contain_exactly(new_plan)
      end

      it "type-casts string params before comparing" do
        new_plan = described_class.new(plan, { amount: "2000" }).execute

        expect(new_plan).to have_attributes(amount: 2000, version: 2)
      end
    end

    context 'when the interval is changed' do
      let(:params) { { interval: "yearly" } }

      it "creates a new version" do
        new_plan = execute

        expect(new_plan).to have_attributes(interval: "yearly", version: 2, previous_plan_id: plan.id)
        expect(plan.reload).to have_attributes(interval: "monthly", archived: true)
      end
    end

    context 'when per_quantity and metric are changed' do
      let(:params) { { per_quantity: true, metric: "api_calls" } }

      it "creates a new version" do
        new_plan = execute

        expect(new_plan).to have_attributes(per_quantity: true, metric: "api_calls", version: 2)
        expect(plan.reload).to have_attributes(per_quantity: false, metric: nil, archived: true)
      end
    end

    context 'when the name and another attribute are changed together' do
      let(:params) { { name: "Starter Plus", amount: 2000 } }

      it "applies both changes to the new version and leaves the old plan untouched" do
        new_plan = execute

        expect(new_plan).to have_attributes(name: "Starter Plus", amount: 2000, version: 2)
        expect(plan.reload).to have_attributes(name: "Starter", amount: 1000, archived: true)
      end
    end

    context 'when versioning a plan that already has a previous version' do
      let!(:plan) { create(:plan, :with_previous_plan, organization: organization) }
      let(:params) { { amount: 5000 } }

      it "builds on the current version" do
        new_plan = execute

        expect(new_plan).to have_attributes(version: plan.version + 1, previous_plan_id: plan.id)
      end

      it "shares one lineage key across every version" do
        new_plan = execute

        expect([plan.previous_plan, plan, new_plan].map(&:lineage_key).uniq).to eq([plan.lineage_key])
      end
    end

    context 'when plans are created independently' do
      it "gives each its own lineage key" do
        other_plan = create(:plan, organization: organization)

        expect(other_plan.lineage_key).to be_present
        expect(other_plan.lineage_key).not_to eq(plan.lineage_key)
      end
    end

    context 'when the plan is archived' do
      let!(:plan) { create(:plan, organization: organization, archived: true) }
      let(:params) { { amount: 2000 } }

      it "raises ConflictError" do
        expect { execute }.to raise_error(ConflictError, "Plan has been archived and can no longer be updated")
      end

      it "does not create a new version or change the plan" do
        expect { execute rescue nil }.not_to change(Plan, :count)
        expect(plan.reload).to have_attributes(amount: 1000, archived: true)
      end

      it "rejects name-only updates too" do
        expect { described_class.new(plan, { name: "Renamed" }).execute }.to raise_error(ConflictError)
        expect(plan.reload.name).to eq("Test Plan")
      end
    end

    context 'when the in-memory plan is stale and was archived by another request' do
      let(:params) { { amount: 3000 } }

      it "sees the archived state after locking and raises ConflictError" do
        stale_plan = Plan.find(plan.id)
        described_class.new(plan, { amount: 2000 }).execute

        expect { described_class.new(stale_plan, params).execute }.to raise_error(ConflictError)
        expect(Plan.count).to eq(2)
      end
    end

    # The lock and the archived check should stop this from happening; the unique index on previous_plan_id is the backstop.
    context 'when another version already points at the plan' do
      let(:params) { { amount: 2000 } }

      before do
        create(:plan, organization: organization, previous_plan: plan, lineage_key: plan.lineage_key, version: 2)
      end

      it "converts the unique violation into ConflictError and rolls back archiving" do
        expect { execute }.to raise_error(ConflictError, "Plan has already been versioned")
        expect(plan.reload).to have_attributes(archived: false, amount: 1000)
        expect(Plan.count).to eq(2)
      end
    end

    context 'when the old plan fails to update' do
      let(:params) { { amount: 2000 } }

      before do
        allow(plan).to receive(:update!).with(archived: true).and_raise(ActiveRecord::RecordNotSaved.new("failed", plan))
      end

      it "raises and does not create a new version" do
        expect { execute }.to raise_error(ActiveRecord::RecordNotSaved)

        expect(Plan.count).to eq(1)
        expect(plan.reload).to have_attributes(archived: false, amount: 1000)
      end
    end
  end

  # Threads need their own DB connections to contend for the row lock, which doesn't work inside
  # the per-example transaction, so this group commits for real and cleans up after itself.
  describe 'concurrent requests' do
    self.use_transactional_tests = false

    # one connection per thread, plus the one the main thread holds for setup and assertions
    let(:thread_count) { ActiveRecord::Base.connection_pool.size - 1 }

    after do
      Plan.where(organization_id: organization.id).delete_all
      organization.destroy
    end

    def run_concurrently(params_for)
      ready = Queue.new
      go = Queue.new

      threads = Array.new(thread_count) do |i|
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            # each request loads its own copy of the plan, like separate HTTP requests would
            plan_copy = Plan.find(plan.id)
            ready << true
            go.pop
            described_class.new(plan_copy, params_for.call(i)).execute
          rescue ConflictError => error
            error
          end
        end
      end

      thread_count.times { ready.pop }
      thread_count.times { go << true }
      threads.map(&:value)
    end

    it "creates exactly one new version when several requests change the amount at once" do
      results = run_concurrently(->(i) { { amount: 2000 + i } })

      new_plans = results.grep(Plan)
      expect(new_plans.size).to eq(1)
      expect(results.grep(ConflictError).size).to eq(thread_count - 1)

      versions = Plan.where(organization_id: organization.id)
      expect(versions.count).to eq(2)
      expect(versions.active.sole).to have_attributes(id: new_plans.first.id, version: 2, previous_plan_id: plan.id)
      expect(versions.pluck(:lineage_key).uniq).to eq([plan.lineage_key])
      expect(plan.reload).to be_archived
    end

    it "applies every name-only update without creating new versions" do
      results = run_concurrently(->(i) { { name: "Name #{i}" } })

      expect(results).to all(eq(plan))
      expect(Plan.where(organization_id: organization.id).count).to eq(1)
      expect(plan.reload.name).to match(/\AName \d\z/)
    end
  end
end
