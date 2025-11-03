# frozen_string_literal: true

module Authenticatable
  extend ActiveSupport::Concern

  private

  def authenticate_user!
    user_id = session[:user_id]
    return render_error(message: "Unauthorized", details: "Not authenticated", status: :unauthorized) if user_id.blank?

    session_record = Auth::SessionStore.new(session: session, user_id: user_id).get_session
    return render_error(message: "Unauthorized", details: "Not authenticated", status: :unauthorized) if session_record.blank?

    @current_user = User.find_by(id: user_id)
    return render_error(message: "Unauthorized", details: "User not found", status: :unauthorized) if @current_user.blank?
  end

  def current_user
    @current_user
  end
end
