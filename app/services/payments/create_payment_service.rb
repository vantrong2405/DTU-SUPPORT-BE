# frozen_string_literal: true

class Payments::CreatePaymentService < BaseService
  PAYMENT_TIMEOUT_MINUTES = 15

  # rubocop:disable Lint/MissingSuper
  def initialize(user:, subscription_plan_id:, payment_method: "momo")
    @user = user
    @subscription_plan = SubscriptionPlan.find(subscription_plan_id)
    @payment_method = payment_method
  end
  # rubocop:enable Lint/MissingSuper

  def call
    validate_inputs!
    create_payment
    create_momo_request
    update_payment_with_momo_response
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
    raise ArgumentError, "Payment method must be momo" unless @payment_method == "momo"
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

  def create_momo_request
    @momo_client = Momo::Client.new
    payment_options = { order_id: @payment.id.to_s, amount: @payment.amount.to_i, order_info: "Subscription: #{@subscription_plan.name}",
redirect_url: ENV.fetch("MOMO_REDIRECT_URL"), ipn_url: ENV.fetch("MOMO_IPN_URL"), extra_data: "", }
    @momo_response = @momo_client.create_payment_request(payment_options)
    raise StandardError, @momo_response[:error] unless @momo_response[:success]
  end

  def update_payment_with_momo_response
    @payment.update!(
      transaction_data: {
        request_id:    @momo_response[:request_id],
        order_id:      @momo_response[:order_id],
        amount:        @momo_response[:amount],
        response_time: @momo_response[:response_time],
        message:       @momo_response[:message],
        pay_url:       @momo_response[:pay_url],
      },
    )
  end
end
