# frozen_string_literal: true

class PaymentsController < ApplicationController
  include Authenticatable

  before_action :authenticate_user!, except: []
  before_action :set_payment, only: %i[show update destroy]
  before_action :authorize_payment!, only: %i[show update destroy]

  def index
    payments = current_user.payments.includes(:subscription_plan).order(created_at: :desc)
    render_success(data: payments.map { |p| serialize_payment(p) })
  end

  def show
    render_success(data: serialize_payment(@payment))
  end

  def create
    result = Payments::CreatePaymentService.call(
      user:                 current_user,
      subscription_plan_id: payment_params[:subscription_plan_id],
      payment_method:       payment_params[:payment_method] || "senpay",
    )

    if result[:success]
      render_success(data: serialize_payment(result[:payment]), status: :created)
    else
      render_error(message: "Failed to create payment", details: result[:error], status: :unprocessable_entity)
    end
  end

  def update
    render_error(message: "Payment cannot be updated", details: "Payments are immutable after creation", status: :method_not_allowed)
  end

  def destroy
    render_error(message: "Payment cannot be deleted", details: "Payments are kept for audit trail", status: :method_not_allowed)
  end

  private

  def set_payment
    @payment = Payment.find(params[:id])
  end

  def authorize_payment!
    return if @payment.user_id == current_user.id

    render_error(message: "Forbidden", details: "You can only access your own payments", status: :forbidden)
  end

  def payment_params
    params.require(:payment).permit(:subscription_plan_id, :payment_method)
  end

  def serialize_payment(payment)
    {
      id:                payment.id,
      amount:            payment.amount.to_f,
      payment_method:    payment.payment_method,
      status:            payment.status,
      checkout_url:      payment.transaction_data&.dig("checkout_url"),
      form_data:         payment.transaction_data&.dig("form_data"),
      expires_at:        payment.expired_at&.iso8601,
      subscription_plan: serialize_subscription_plan(payment),
      timestamps:        serialize_timestamps(payment),
    }
  end

  def serialize_subscription_plan(payment)
    {
      id:    payment.subscription_plan_id,
      name:  payment.subscription_plan&.name,
      price: payment.subscription_plan&.price&.to_f,
    }
  end

  def serialize_timestamps(payment)
    {
      created_at: payment.created_at.iso8601,
      updated_at: payment.updated_at.iso8601,
    }
  end
end
