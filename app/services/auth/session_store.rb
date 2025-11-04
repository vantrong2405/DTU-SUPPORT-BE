# frozen_string_literal: true

class Auth::SessionStore < BaseService
  attr_reader :session, :user_id

  def initialize(session:, user_id:)
    @session = session
    @user_id = user_id
    super()
  end

  def session_data
    @session[cache_key]
  end

  def store_session(access_token: nil, refresh_token: nil)
    @session[cache_key] = {
      user_id:,
      access_token:,
      refresh_token:,
    }
  end

  def remove_tokens
    @session.delete(cache_key)
  end

  private

  def cache_key
    @cache_key ||= "auth_session_user_#{user_id}"
  end
end
