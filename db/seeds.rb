# frozen_string_literal: true

# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

SubscriptionPlan.find_or_create_by!(name: "Gói Basic") do |plan|
  plan.price = 100_000
  plan.duration_days = 30
  plan.features = {
    "ai_limit" => 50,
    "crawl_limit" => 20
  }
  plan.is_active = true
end

SubscriptionPlan.find_or_create_by!(name: "Gói Pro") do |plan|
  plan.price = 200_000
  plan.duration_days = 30
  plan.features = {
    "ai_limit" => 150,
    "crawl_limit" => 50
  }
  plan.is_active = true
end

SubscriptionPlan.find_or_create_by!(name: "Gói Premium") do |plan|
  plan.price = 300_000
  plan.duration_days = 30
  plan.features = {
    "ai_limit" => 300,
    "crawl_limit" => 100
  }
  plan.is_active = true
end
