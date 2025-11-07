# frozen_string_literal: true

class Payment < ApplicationRecord
  belongs_to :user
  belongs_to :subscription_plan

  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :payment_method, presence: true
  validates :status, presence: true

  # Status values: pending, success, failed, expired, cancelled
  scope :success, -> { where(status: "success") }
  scope :pending, -> { where(status: "pending") }
  scope :failed, -> { where(status: "failed") }
  scope :expired, -> { where(status: "expired") }
  scope :recent, -> { order(created_at: :desc) }
  scope :expired_pending, -> { pending.where("expired_at < ?", Time.current) }

  def expired?
    expired_at.present? && expired_at < Time.current
  end

  def success?
    status == "success"
  end

  def pending?
    status == "pending"
  end

  def failed?
    status == "failed"
  end
end
