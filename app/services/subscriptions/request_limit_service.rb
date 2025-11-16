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

    remaining_requests(user) > 0
  end

  def consume_request(user)
    return { success: false, error: I18n.t("errors.no_active_subscription") } unless can_use_ai_chatbox?(user)

    { success: true }
  end

  private

  def count_used_requests(user)
    # Count all requests for user with subscription plan
    # Reset count based on subscription plan duration if needed
    user.ai_schedule_results.count
  end
end
