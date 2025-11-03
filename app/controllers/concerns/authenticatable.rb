# frozen_string_literal: true

module Authenticatable
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_user!
  end

  private

  def authenticate_user!
    user_id = session_cache.user_id

    unless user_id.present?
      render_error(message: "Unauthorized", details: "Not authenticated", status: :unauthorized)
      return
    end

    @current_user = User.find_by(id: user_id)

    unless @current_user
      clear_session_and_render_error
      return
    end

    @current_user
  rescue ActiveRecord::RecordNotFound
    clear_session_and_render_error
  end

  def current_user
    @current_user
  end

  def session_cache
    @session_cache ||= Services::Auth::SessionCacheService.new(session: session)
  end

  def clear_session_and_render_error
    session_cache.remove_user_id
    render_error(message: "Unauthorized", details: "User not found", status: :unauthorized)
  end
end
