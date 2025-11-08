# frozen_string_literal: true

class Webhooks::SenpayController < ApplicationController
  def callback
    result = Payments::ProcessWebhookService.call(webhook_params: webhook_params.to_h)

    if result[:success]
      render_success_response
    else
      render_error_response(result[:error])
    end
  rescue StandardError => e
    handle_error(e)
  end

  private

  def render_success_response
    render json: { success: true }, status: :ok
  end

  def render_error_response(error)
    Rails.logger.error("SenPay webhook processing failed: #{error}")
    render json: { success: false, error: error }, status: :unprocessable_entity
  end

  def handle_error(error)
    Rails.logger.error("SenPay webhook error: #{error.class} - #{error.message}")
    Rails.logger.error(error.backtrace.join("\n")) if error.backtrace
    render json: { success: false, error: "Internal server error" }, status: :internal_server_error
  end

  def webhook_params
    params.permit(
      :notification_type,
      :signature,
      order: [:order_invoice_number, :order_amount, :order_status],
      transaction: [
        :id, :gateway, :transaction_date, :amount_in, :amount_out,
        :accumulated, :code, :reference_number, :transaction_content,
        :account_number, :sub_account
      ]
    )
  end
end
