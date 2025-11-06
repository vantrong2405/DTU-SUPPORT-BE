# frozen_string_literal: true

class Payments::ProcessWebhookService < BaseService
  def initialize(webhook_params:)
    @webhook_params = webhook_params.with_indifferent_access
  end

  def call
    verify_signature!
    find_payment!
    check_already_processed!
    update_payment_status!
    activate_subscription! if payment_success?
    { success: true, payment: @payment }
  rescue StandardError => e
    Rails.logger.error("Webhook processing failed: #{e.class} - #{e.message}")
    Rails.logger.error(e.backtrace.join("\n")) if e.backtrace
    { success: false, error: e.message }
  end

  private

  def verify_signature!
    @momo_client = Momo::Client.new
    unless @momo_client.verify_webhook_signature(@webhook_params)
      raise StandardError, "Invalid webhook signature"
    end
  end

  def find_payment!
    order_id = @webhook_params[:orderId] || @webhook_params["orderId"]
    @payment = Payment.find_by(id: order_id)
    raise StandardError, "Payment not found: #{order_id}" if @payment.blank?
  end

  def check_already_processed!
    return unless @payment.success?

    Rails.logger.info("Payment #{@payment.id} already processed, skipping")
    raise StandardError, "Payment already processed"
  end

  def update_payment_status!
    new_status = payment_success? ? "success" : "failed"
    transaction_data_update = extract_transaction_data

    @payment.update!(
      status:           new_status,
      transaction_data: (@payment.transaction_data || {}).merge(transaction_data_update),
    )

    Rails.logger.info("Payment #{@payment.id} status updated to #{new_status}")
  end

  def extract_transaction_data
    {
      trans_id:      get_param(:transId),
      result_code:   get_param(:resultCode),
      message:       get_param(:message),
      pay_type:      get_param(:payType),
      response_time: get_param(:responseTime),
      extra_data:    get_param(:extraData),
    }
  end

  def get_param(key)
    @webhook_params[key] || @webhook_params[key.to_s]
  end

  def payment_success?
    result_code = get_param(:resultCode)
    result_code.to_i == 0
  end

  def activate_subscription!
    Subscriptions::ActivateService.call(
      user:              @payment.user,
      subscription_plan: @payment.subscription_plan,
      payment:           @payment,
    )
  end
end
