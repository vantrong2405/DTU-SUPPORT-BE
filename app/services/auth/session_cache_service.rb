# frozen_string_literal: true

class Services::Auth::SessionCacheService < Services::BaseService
  CACHE_LIFETIME = 1.hour

  attr_reader :session, :user_id

  def initialize(session:, user_id: nil)
    @session = session
    @user_id = user_id
  end

  def store_user_id(user_id:)
    @user_id = user_id
    @session[cache_key(user_id: user_id)] = {
      user_id: user_id,
      expires_at: CACHE_LIFETIME.from_now
    }
  end

  def user_id
    return @user_id if @user_id.present?

    key = cache_key_for_current_user
    return nil if key.blank?

    cached_data = @session[key]
    return nil if cached_data.blank? || expired?(cached_data, key)

    @user_id = cached_data[:user_id]
  end

  def remove_user_id
    return unless user_id.present?

    @session.delete(cache_key(user_id: user_id))
    @user_id = nil
  end

  private

  def cache_key(user_id:)
    "user_session_user_#{user_id}"
  end

  def cache_key_for_current_user
    @session.keys.find { |key| key.to_s.start_with?("user_session_user_") }
  end

  def expired?(cached_data, key)
    return false unless cached_data[:expires_at]

    if Time.current > cached_data[:expires_at]
      @session.delete(key)
      true
    else
      false
    end
  end
end
