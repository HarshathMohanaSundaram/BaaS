class Stripe::CreateAndSendAccountLinkJob < ApplicationJob
  queue_as :default

  def perform(organization_id)
    organization = Organization.find(organization_id)

    return if organization.stripe_account_id.blank?

    account_link = Stripe.create_account_link(organization)
    return if account_link.blank?

    # Send the account link to the organization's email
    AccountLinkMailer.with(organization: organization, account_link: account_link).send_account_link.deliver_later
  end
end
