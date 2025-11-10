# frozen_string_literal: true

Rails.application.config.after_initialize do
  required_vars = %w[
    SENPAY_MERCHANT_ID
    SENPAY_SECRET_KEY
  ]

  missing_vars = required_vars.reject { |var| ENV[var].present? }

  if missing_vars.any? && Rails.env.production?
    Rails.logger.error("Missing required SenPay environment variables: #{missing_vars.join(', ')}")
    raise "Missing required SenPay environment variables: #{missing_vars.join(', ')}"
  elsif missing_vars.any?
    Rails.logger.warn("Missing SenPay environment variables (optional in #{Rails.env}): #{missing_vars.join(', ')}")
  end

  Rails.application.config.senpay = {
    merchant_id:  ENV.fetch("SENPAY_MERCHANT_ID", nil),
    secret_key:   ENV.fetch("SENPAY_SECRET_KEY", nil),
    api_url:      ENV.fetch("SENPAY_API_URL", nil) || Rails.application.config.secrets.senpay[:api_url],
    checkout_url: ENV.fetch("SENPAY_CHECKOUT_URL", nil) || Rails.application.config.secrets.senpay[:checkout_url],
    redirect_url: ENV.fetch("SENPAY_REDIRECT_URL", nil),
    webhook_url:  ENV.fetch("SENPAY_WEBHOOK_URL", nil),
  }
end
