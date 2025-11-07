# frozen_string_literal: true

class Payments::ExpirePaymentsJob < ApplicationJob
  queue_as :default

  def perform
    expired_payments = Payment.pending.where("expired_at < ?", Time.current)

    expired_payments.find_each do |payment|
      payment.update!(status: "expired")
      Rails.logger.info("Payment #{payment.id} expired")
    end

    Rails.logger.info("Expired #{expired_payments.count} payments")
  end
end
