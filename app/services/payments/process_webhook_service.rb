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
    @senpay_client = Senpay::Client.new
    signature = @webhook_params[:signature] || @webhook_params["signature"]
    unless @senpay_client.verify_webhook_signature(@webhook_params, signature)
      raise StandardError, "Invalid webhook signature"
    end
  end

  def find_payment!
    order_invoice_number = @webhook_params.dig(:order, :order_invoice_number) ||
                           @webhook_params.dig("order", "order_invoice_number")
    @payment = Payment.find_by(id: order_invoice_number)
    raise StandardError, "Payment not found: #{order_invoice_number}" if @payment.blank?
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
    order_data = @webhook_params[:order] || @webhook_params["order"] || {}
    transaction_data = @webhook_params[:transaction] || @webhook_params["transaction"] || {}

    {
      notification_type: get_param(:notification_type),
      order: {
        order_invoice_number: order_data[:order_invoice_number] || order_data["order_invoice_number"],
        order_amount: order_data[:order_amount] || order_data["order_amount"],
        order_status: order_data[:order_status] || order_data["order_status"],
      },
      transaction: {
        id: transaction_data[:id] || transaction_data["id"],
        gateway: transaction_data[:gateway] || transaction_data["gateway"],
        transaction_date: transaction_data[:transaction_date] || transaction_data["transaction_date"],
        amount_in: transaction_data[:amount_in] || transaction_data["amount_in"],
        amount_out: transaction_data[:amount_out] || transaction_data["amount_out"],
        accumulated: transaction_data[:accumulated] || transaction_data["accumulated"],
        code: transaction_data[:code] || transaction_data["code"],
        reference_number: transaction_data[:reference_number] || transaction_data["reference_number"],
        transaction_content: transaction_data[:transaction_content] || transaction_data["transaction_content"],
        account_number: transaction_data[:account_number] || transaction_data["account_number"],
        sub_account: transaction_data[:sub_account] || transaction_data["sub_account"],
      },
    }
  end

  def get_param(key)
    @webhook_params[key] || @webhook_params[key.to_s]
  end

  def payment_success?
    notification_type = get_param(:notification_type)
    notification_type == "ORDER_PAID"
  end

  def activate_subscription!
    Subscriptions::ActivateService.call(
      user:              @payment.user,
      subscription_plan: @payment.subscription_plan,
      payment:           @payment,
    )
  end
end
