# frozen_string_literal: true

class Subscriptions::ActivateService < BaseService
  def initialize(user:, subscription_plan:, payment:)
    @user = user
    @subscription_plan = subscription_plan
    @payment = payment
  end

  def call
    ActiveRecord::Base.transaction do
      activate_subscription!
      log_activation
      { success: true, user: @user }
    end
  rescue StandardError => e
    Rails.logger.error("Subscription activation failed: #{e.class} - #{e.message}")
    Rails.logger.error(e.backtrace.join("\n")) if e.backtrace
    raise
  end

  private

  def activate_subscription!
    @user.update!(subscription_plan: @subscription_plan)
  end

  def log_activation
    Rails.logger.info("Subscription activated: User #{@user.id}, Plan #{@subscription_plan.id}, Payment #{@payment.id}")
  end
end
