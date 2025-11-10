# frozen_string_literal: true

class Payments::CreatePaymentService < BaseService
  PAYMENT_TIMEOUT_MINUTES = 15

  # rubocop:disable Lint/MissingSuper
  def initialize(user:, subscription_plan_id:, payment_method: "senpay")
    @user = user
    @subscription_plan = SubscriptionPlan.find(subscription_plan_id)
    @payment_method = payment_method
  end
  # rubocop:enable Lint/MissingSuper

  def call
    validate_inputs!
    create_payment
    create_senpay_request
    update_payment_with_senpay_response
    { success: true, payment: @payment }
  rescue StandardError => e
    Rails.logger.error("Payment creation failed: #{e.class} - #{e.message}")
    Rails.logger.error(e.backtrace.join("\n")) if e.backtrace
    { success: false, error: e.message }
  end

  private

  def validate_inputs!
    raise ArgumentError, "User is required" if @user.blank?
    raise ArgumentError, "Subscription plan not found" if @subscription_plan.blank?
    raise ArgumentError, "Subscription plan is not active" unless @subscription_plan.is_active?
    raise ArgumentError, "Payment method must be senpay" unless @payment_method == "senpay"
  end

  def create_payment
    @payment = Payment.create!(
      user:              @user,
      subscription_plan: @subscription_plan,
      amount:            @subscription_plan.price,
      payment_method:    @payment_method,
      status:            "pending",
      expired_at:        Time.current + PAYMENT_TIMEOUT_MINUTES.minutes,
    )
  end

  def create_senpay_request
    @senpay_client = Senpay::Client.new
    senpay_config = Rails.application.config.senpay

    # Validate URLs
    redirect_url = senpay_config[:redirect_url]
    webhook_url = senpay_config[:webhook_url]

    Rails.logger.info("SenPay URLs - redirect_url: #{redirect_url}, webhook_url: #{webhook_url}")

    # Warn if URLs are not HTTPS (except localhost for development)
    if redirect_url.present? && !redirect_url.start_with?("https://") && !redirect_url.start_with?("http://localhost")
      Rails.logger.warn("SenPay redirect_url should be HTTPS: #{redirect_url}")
    end

    if webhook_url.present? && !webhook_url.start_with?("https://")
      Rails.logger.warn("SenPay webhook_url must be HTTPS: #{webhook_url}")
    end

    payment_params = {
      order_amount: @payment.amount.to_i,
      order_invoice_number: @payment.id.to_s,
      order_description: "Subscription: #{@subscription_plan.name}",
      return_url: redirect_url,
      ipn_url: webhook_url,
    }

    # BE config tất cả: tạo form data với signature
    # FE chỉ cần submit form (không cần config gì thêm)
    @senpay_response = @senpay_client.create_payment_request(payment_params)
  end

  def update_payment_with_senpay_response
    @payment.update!(
      transaction_data: {
        checkout_url: @senpay_response[:checkout_url],
        form_data: @senpay_response[:form_data],
      },
    )
  end
end
