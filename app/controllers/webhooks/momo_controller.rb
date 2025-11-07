# frozen_string_literal: true

class ::Webhooks::MomoController < ApplicationController
  skip_before_action :verify_authenticity_token, if: :verify_authenticity_token

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
    render json: { resultCode: 0, message: "Success" }, status: :ok
  end

  def render_error_response(error)
    Rails.logger.error("MoMo webhook processing failed: #{error}")
    render json: { resultCode: 1, message: error }, status: :unprocessable_entity
  end

  def handle_error(error)
    Rails.logger.error("MoMo webhook error: #{error.class} - #{error.message}")
    Rails.logger.error(error.backtrace.join("\n")) if error.backtrace
    render json: { resultCode: 1, message: "Internal server error" }, status: :internal_server_error
  end

  def webhook_params
    params.permit(
      :partnerCode, :orderId, :requestId, :amount, :orderInfo, :orderType,
      :transId, :resultCode, :message, :payType, :responseTime, :extraData,
      :signature,
    )
  end
end
