# frozen_string_literal: true

class SubscriptionPlanSerializer < BaseSerializer
  attributes :id, :name, :price, :duration_days, :features, :ai_limit, :crawl_limit, :created_at, :updated_at

  attribute :price do |plan|
    plan.price.to_f
  end

  attribute :features do |plan|
    plan.features || {}
  end

  attribute :ai_limit do |plan|
    plan.ai_limit
  end

  attribute :crawl_limit do |plan|
    plan.crawl_limit
  end
end
