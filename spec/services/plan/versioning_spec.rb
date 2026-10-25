require 'rails_helper'

RSpec.describe Plan::Versioning do
  let(:organization) { create(:organization) }
  let!(:plan) { create(:plan, organization: organization, name: "Starter", amount: 1000, interval: :monthly) }

  subject(:execute) { described_class.new(plan, params).execute }

  describe '#execute' do
    context 'when only the name is changed' do
      let(:params) { { name: "Starter Plus" } }

      it "updates the plan in place" do
        expect(execute).to be(true)
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

      it "does not create a new version" do
        expect { execute }.not_to change(Plan, :count)
        expect(execute).to be(true)
      end

      it "compares type-cast values, so string params matching the current values are not a change" do
        expect { described_class.new(plan, { amount: "1000" }).execute }.not_to change(Plan, :count)
      end
    end

    context 'when the name update is invalid' do
      let(:params) { { name: "" } }

      it "returns false with errors and does not create a new version" do
        expect { expect(execute).to be(false) }.not_to change(Plan, :count)
        expect(plan.errors[:name]).to include("can't be blank")
        expect(plan.reload.name).to eq("Starter")
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

      it "keeps the lineage key on the archived old plan" do
        expect { execute }.not_to change { plan.reload.lineage_key }
      end

      it "archives the old plan and keeps its original attributes" do
        execute

        expect(plan.reload).to have_attributes(archived: true, amount: 1000, version: 1)
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

    context 'when params try to change the lineage key' do
      let(:other_lineage_key) { SecureRandom.uuid }

      it "ignores it on a versioned change" do
        new_plan = described_class.new(plan, { amount: 2000, lineage_key: other_lineage_key }).execute

        expect(new_plan).to have_attributes(amount: 2000, version: 2, lineage_key: plan.lineage_key)
        expect(plan.reload.lineage_key).not_to eq(other_lineage_key)
      end

      it "ignores it on a name-only change" do
        expect(described_class.new(plan, { name: "Starter Plus", lineage_key: other_lineage_key }).execute).to be(true)
        expect(plan.reload).to have_attributes(name: "Starter Plus", lineage_key: plan.lineage_key)
        expect(plan.lineage_key).not_to eq(other_lineage_key)
      end

      it "does not create a new version when it is the only change" do
        expect { described_class.new(plan, { lineage_key: other_lineage_key }).execute }.not_to change(Plan, :count)
        expect(plan.reload.lineage_key).not_to eq(other_lineage_key)
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

      it "returns false with an error" do
        expect(execute).to be(false)
        expect(plan.errors[:base]).to include("has been archived and can no longer be updated")
      end

      it "does not create a new version or change the plan" do
        expect { execute }.not_to change(Plan, :count)
        expect(plan.reload).to have_attributes(amount: 1000, archived: true)
      end

      it "rejects name-only updates too" do
        expect(described_class.new(plan, { name: "Renamed" }).execute).to be(false)
        expect(plan.reload.name).to eq("Test Plan")
      end
    end

    context 'when the in-memory plan is stale and was archived by another request' do
      let(:params) { { amount: 3000 } }

      it "sees the archived state after locking and rejects the update" do
        stale_plan = Plan.find(plan.id)
        described_class.new(plan, { amount: 2000 }).execute

        expect { expect(described_class.new(stale_plan, params).execute).to be(false) }.not_to change(Plan, :count)
        expect(stale_plan.errors[:base]).to include("has been archived and can no longer be updated")
      end
    end

    context 'when the new plan fails to save' do
      let(:params) { { amount: -1 } }

      it "raises and rolls back archiving the old plan" do
        expect { execute }.to raise_error(ActiveRecord::RecordInvalid)

        expect(Plan.count).to eq(1)
        expect(plan.reload).to have_attributes(archived: false, amount: 1000, version: 1)
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

    let(:thread_count) { 4 }

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
      expect(results.count(false)).to eq(thread_count - 1)

      versions = Plan.where(organization_id: organization.id)
      expect(versions.count).to eq(2)
      expect(versions.active.sole).to have_attributes(id: new_plans.first.id, version: 2, previous_plan_id: plan.id)
      expect(versions.pluck(:lineage_key).uniq).to eq([plan.lineage_key])
      expect(plan.reload).to be_archived
    end

    it "applies every name-only update without creating new versions" do
      results = run_concurrently(->(i) { { name: "Name #{i}" } })

      expect(results).to all(be(true))
      expect(Plan.where(organization_id: organization.id).count).to eq(1)
      expect(plan.reload.name).to match(/\AName \d\z/)
    end
  end
end
