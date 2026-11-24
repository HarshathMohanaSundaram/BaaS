credentials = Rails.application.config_for(:stripe)

Stripe.api_key = credentials[:secret_key]
Stripe.api_version = credentials[:api_version]
