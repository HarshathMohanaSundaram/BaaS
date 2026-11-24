class Stripe
  class << self
    def create_account(organization)
      Stripe::Account.create(
        type: "custom",
        country: "us",
        email: organization.email,
        business_type: organization.business_type,
        business_profile: { name: organization.name },
        capabilities: {
          card_payments: { requested: true },
          transfers: { requested: true }
        },
        metadata: { organization_id: organization.id },
        idempotency_key: "create_account_#{organization.id}_#{Time.now.to_i}"
      )
    end

    def create_account_link(organization)
      Stripe::AccountLink.create(
        account: organization.stripe_account_id,
        refresh_url: organization.refresh_url,
        return_url: organization.return_url,
        type: "account_onboarding"
      )
    end

    def create_customer(customer)
      Stripe::Customer.create(
        email: customer.email,
        name: customer.name,
        metadata: { organization_id: customer.organization_id, external_id: customer.external_id },
        stripe_account_id: customer.stripe_account_id,
        idempotency_key: "create_customer_#{customer.organization_id}_#{customer.external_id}_#{Time.now.to_i}"
      )
    end
  end
end
