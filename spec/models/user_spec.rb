require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'validations' do
    let(:organization) { create(:organization) }
    let(:user) { create(:user, organization: organization) }
    let(:dup) { build(:user, email: user.email, organization: user.organization) }

    before { user }

    it "rejects a duplicate email at the model level" do
      expect(dup.valid?).to be_falsey
      expect(dup.errors[:email]).to include("has already been taken")
    end

    it "rejects a duplicate email at the database level" do
      expect { dup.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end
end
