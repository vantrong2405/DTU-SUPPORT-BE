# frozen_string_literal: true

class SubscriptionPlansController < ApplicationController
  def index
    plans = SubscriptionPlan.active.order(:price)
    render json: SubscriptionPlanSerializer.new(plans).serializable_hash, status: :ok
  end
end
