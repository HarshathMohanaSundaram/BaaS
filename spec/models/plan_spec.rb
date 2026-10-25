require 'rails_helper'

RSpec.describe Plan, type: :model do
  describe 'validations' do
    let(:plan) { build(:plan) }

    it "is valid with the default factory" do
      expect(plan).to be_valid
    end

    it "requires a name" do
      plan.name = nil
      expect(plan).not_to be_valid
      expect(plan.errors[:name]).to include("can't be blank")
    end

    it "requires an interval" do
      plan.interval = nil
      expect(plan).not_to be_valid
      expect(plan.errors[:interval]).to include("can't be blank")
    end

    it "requires a version" do
      plan.version = nil
      expect(plan).not_to be_valid
      expect(plan.errors[:version]).to include("can't be blank")
    end

    describe 'amount' do
      it "is required" do
        plan.amount = nil
        expect(plan).not_to be_valid
        expect(plan.errors[:amount]).to include("can't be blank")
      end

      it "must be an integer" do
        plan.amount = 10.5
        expect(plan).not_to be_valid
        expect(plan.errors[:amount]).to include("must be an integer")
      end

      it "cannot be negative" do
        plan.amount = -1
        expect(plan).not_to be_valid
        expect(plan.errors[:amount]).to include("must be greater than or equal to 0")
      end

      it "allows zero" do
        plan.amount = 0
        expect(plan).to be_valid
      end
    end

    describe 'metric' do
      it "is required for a per-quantity plan" do
        plan = build(:plan, :per_quantity, metric: nil)
        expect(plan).not_to be_valid
        expect(plan.errors[:metric]).to include("can't be blank")
      end

      it "is valid on a per-quantity plan when set" do
        expect(build(:plan, :per_quantity)).to be_valid
      end

      it "must be absent for a flat plan" do
        plan.metric = "api_calls"
        expect(plan).not_to be_valid
        expect(plan.errors[:metric]).to include("must be blank")
      end

      it "normalizes an empty string to nil so a flat plan saves" do
        plan.metric = ""
        expect(plan.metric).to be_nil
        expect { plan.save! }.not_to raise_error
      end

      it "normalizes an empty string to nil so a per-quantity plan still requires a metric" do
        plan = build(:plan, :per_quantity, metric: "")
        expect(plan).not_to be_valid
        expect(plan.errors[:metric]).to include("can't be blank")
      end
    end

    describe 'previous_plan' do
      it "is valid when the previous plan belongs to the same organization" do
        expect(build(:plan, :with_previous_plan)).to be_valid
      end

      it "is invalid when the previous plan belongs to another organization" do
        other_org_plan = create(:plan, archived: true)
        plan = build(:plan, previous_plan: other_org_plan, version: 2)

        expect(plan).not_to be_valid
        expect(plan.errors[:previous_plan]).to include("must belong to the same organization")
      end
    end
  end

  describe 'associations' do
    it "returns the parent row through previous_plan" do
      parent = create(:plan, archived: true)
      plan = create(:plan, organization: parent.organization, previous_plan: parent, version: 2)

      expect(Plan.find(plan.id).previous_plan).to eq(parent)
    end
  end

  describe '.active' do
    it "returns only plans that are not archived" do
      organization = create(:organization)
      live = create(:plan, organization: organization)
      create(:plan, organization: organization, archived: true)

      expect(Plan.active).to contain_exactly(live)
    end
  end

  # These bypass model validations to prove the database enforces each rule on its own.
  describe 'database constraints' do
    let(:plan) { build(:plan) }

    %i[name amount interval version].each do |column|
      it "rejects a null #{column}" do
        plan[column] = nil
        expect { plan.save!(validate: false) }.to raise_error(ActiveRecord::NotNullViolation)
      end
    end

    it "rejects a null organization_id" do
      # Clear the association, not just the column, or the loaded organization repopulates it on save.
      plan.organization = nil
      expect { plan.save!(validate: false) }.to raise_error(ActiveRecord::NotNullViolation)
    end

    it "rejects a nonexistent organization" do
      plan.organization_id = -1
      expect { plan.save!(validate: false) }.to raise_error(ActiveRecord::InvalidForeignKey)
    end

    it "rejects a nonexistent previous plan" do
      plan.previous_plan_id = -1
      expect { plan.save!(validate: false) }.to raise_error(ActiveRecord::InvalidForeignKey)
    end

    it "rejects two plans pointing at the same previous plan" do
      existing = create(:plan, :with_previous_plan)
      plan = build(:plan, organization: existing.organization, previous_plan: existing.previous_plan, version: 2)

      expect { plan.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "rejects a negative amount" do
      plan.amount = -1
      expect { plan.save!(validate: false) }.to raise_error(ActiveRecord::StatementInvalid, /amount_non_negative/)
    end

    it "rejects an interval outside the enum" do
      plan.save!
      # Raw SQL, since assigning an unknown value through the enum raises before reaching the DB.
      expect { Plan.where(id: plan.id).update_all("interval = 3") }
        .to raise_error(ActiveRecord::StatementInvalid, /interval_valid/)
    end

    describe 'per_quantity / metric consistency' do
      it "rejects a per-quantity plan without a metric" do
        plan = build(:plan, :per_quantity, metric: nil)
        expect { plan.save!(validate: false) }
          .to raise_error(ActiveRecord::StatementInvalid, /per_quantity_metric_consistency/)
      end

      it "rejects a flat plan with a metric" do
        plan.metric = "api_calls"
        expect { plan.save!(validate: false) }
          .to raise_error(ActiveRecord::StatementInvalid, /per_quantity_metric_consistency/)
      end
    end

    it "prevents deleting a plan that is referenced as a previous plan" do
      plan = create(:plan, :with_previous_plan)
      expect { plan.previous_plan.delete }.to raise_error(ActiveRecord::InvalidForeignKey)
    end
  end
end
