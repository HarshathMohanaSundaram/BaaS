class Stripe::CreateCustomerJob < ApplicationJob
  queue_as :default

  def perform(customer_id, organization_id)
    customer = Customer.find_by_id(customer_id)
    organization = Organization.find_by_id(organization_id)

    return if customer.stripe_customer_id.present?
    return if organization.stripe_account_id.blank?

    stripe_customer = Stripe.create_customer(customer)
    customer.update!(stripe_customer_id: stripe_customer.id) if stripe_customer.id.present?
  end
end
