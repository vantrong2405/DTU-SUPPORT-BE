# frozen_string_literal: true

class Subscriptions::RequestLimitService < BaseService
  def self.remaining_requests(user)
    new.remaining_requests(user)
  end

  def self.can_use_ai_chatbox?(user)
    new.can_use_ai_chatbox?(user)
  end

  def self.consume_request(user)
    new.consume_request(user)
  end

  def remaining_requests(user)
    return 0 unless user.subscription_plan_id

    limit = user.subscription_plan.ai_limit
    used = count_used_requests(user)
    [limit - used, 0].max
  end

  def can_use_ai_chatbox?(user)
    return false unless user.subscription_plan_id
    return false unless active_subscription?(user)

    remaining_requests(user) > 0
  end

  def consume_request(user)
    return { success: false, error: "No active subscription" } unless can_use_ai_chatbox?(user)

    { success: true }
  end

  private

  def active_subscription?(user)
    return false unless user.subscription_plan_id

    latest_payment = user.payments.success.recent.first
    return false unless latest_payment

    expires_at = latest_payment.created_at + user.subscription_plan.duration_days.days
    expires_at > Time.current
  end

  def count_used_requests(user)
    subscription_start = get_subscription_start(user)
    return 0 unless subscription_start

    user.ai_schedule_results.where("created_at >= ?", subscription_start).count
  end

  def get_subscription_start(user)
    latest_payment = user.payments.success.recent.first
    return nil unless latest_payment

    latest_payment.created_at
  end
end
