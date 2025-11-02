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
end
