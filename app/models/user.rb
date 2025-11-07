# frozen_string_literal: true

class User < ApplicationRecord
  has_many :payments, dependent: :destroy
  has_many :crawl_course_configs, dependent: :destroy
  has_many :ai_schedule_results, dependent: :destroy
  belongs_to :subscription_plan, optional: true

  validates :email, presence: true, uniqueness: true

  def google_tokens
    tokens || {}
  end

  def token_valid?
    token = google_tokens
    return false if token.blank?

    token["access_token"].present? && token["refresh_token"].present?
  end

  def access_token
    tokens&.dig("access_token")
  end

  def refresh_token
    tokens&.dig("refresh_token")
  end

  # Subscription methods
  def current_ai_request_limit
    return 0 unless subscription_plan_id

    subscription_plan&.ai_limit || 0
  end

  def remaining_ai_requests
    Subscriptions::RequestLimitService.remaining_requests(self)
  end

  def can_use_ai_chatbox?
    Subscriptions::RequestLimitService.can_use_ai_chatbox?(self)
  end

  def active_subscription?
    return false unless subscription_plan_id

    latest_payment = payments.success.recent.first
    return false unless latest_payment

    expires_at = latest_payment.created_at + subscription_plan.duration_days.days
    expires_at > Time.current
  end

  def subscription_expires_at
    return nil unless subscription_plan_id

    latest_payment = payments.success.recent.first
    return nil unless latest_payment

    latest_payment.created_at + subscription_plan.duration_days.days
  end
end
