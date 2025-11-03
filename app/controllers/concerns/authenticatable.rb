# frozen_string_literal: true

module Authenticatable
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_user!
  end

  private

  def authenticate_user!
    session_cache = Services::Auth::SessionCacheService.new(session: session)
    user_id = session_cache.user_id

    unless user_id.present?
      render_error(message: "Unauthorized", details: "Not authenticated", status: :unauthorized)
      return
    end

    @current_user = User.find_by(id: user_id)

    unless @current_user
      session_cache.remove_user_id
      render_error(message: "Unauthorized", details: "User not found", status: :unauthorized)
      return
    end

    @current_user
  rescue ActiveRecord::RecordNotFound
    session_cache = Services::Auth::SessionCacheService.new(session: session)
    session_cache.remove_user_id
    render_error(message: "Unauthorized", details: "User not found", status: :unauthorized)
  end

  def current_user
    @current_user
  end
end
