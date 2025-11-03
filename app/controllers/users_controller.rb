# frozen_string_literal: true

class UsersController < ApplicationController
  include Authenticatable

  def show
    user = params[:id] == "me" ? current_user : User.find(params[:id])

    render_success(data: {
      id: user.id,
      email: user.email,
      name: user.name,
      subscription_plan_id: user.subscription_plan_id
    })
  end
end
