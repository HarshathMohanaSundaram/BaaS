require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'validations' do
    let(:organization) { create(:organization) }
    let(:user) { create(:user) }
    let(:dup) { build(:user, email: user.email, organization: organization) }

    before { user }

    it "rejects a duplicate email at the database level" do
      expect { dup.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end
end
