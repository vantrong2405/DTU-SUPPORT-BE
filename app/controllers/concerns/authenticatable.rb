# frozen_string_literal: true

module Authenticatable
  extend ActiveSupport::Concern

  private

  def authenticate_user!
    user_id = session[:user_id]
    render_error(message: "Unauthorized", details: "Not authenticated", status: :unauthorized) and return if user_id.blank?

    @current_user = User.find_by(id: user_id)
    render_error(message: "Unauthorized", details: "User not found", status: :unauthorized) and return if @current_user.blank?
  end

  def current_user
    @current_user
  end
end
