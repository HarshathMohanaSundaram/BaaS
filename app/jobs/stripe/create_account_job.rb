class Stripe::CreateAccountJob < ApplicationJob
  queue_as :default

  def perform(organization_id)
    organization = Organization.find(organization_id)

    return if organization.stripe_account_id.present?

    account = Stripe.create_account(organization)
    organization.update!(stripe_account_id: account.id) if account.id.present?
  end
end
