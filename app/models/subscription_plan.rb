# frozen_string_literal: true

class SubscriptionPlan < ApplicationRecord
  has_many :users, dependent: :nullify
  has_many :payments, dependent: :restrict_with_error

  validates :name, presence: true
  validates :price, presence: true, numericality: { greater_than: 0 }
  validates :duration_days, presence: true, numericality: { greater_than: 0 }

  scope :active, -> { where(is_active: true) }

  def ai_limit
    features&.dig("ai_limit") || 0
  end

  def crawl_limit
    features&.dig("crawl_limit") || 0
  end
end
