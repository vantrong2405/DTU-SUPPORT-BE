# frozen_string_literal: true

class Oauth::GoogleController < ApplicationController
  def redirect
    oauth_url = GoogleOauth::Client.generate_auth_url(
      base_url: request.base_url,
      return_url: params[:return_url] || request.referer
    )

    redirect_to oauth_url, allow_other_host: true
  rescue StandardError => e
    render_error(message: e.message, details: "Failed to generate OAuth URL", status: :bad_request)
  end

  def callback
    state = GoogleOauth::Client.decode_state(params[:state])

    unless params[:code].present? && state.present?
      render_error(message: "Invalid OAuth callback", details: "Missing code or state parameter", status: :bad_request)
      return
    end

    token_response = GoogleOauth::Client.exchange_code_for_token(
      code: params[:code],
      redirect_uri: "#{request.base_url}/oauth/google/callback"
    )

    unless token_response
      render_error(message: "Failed to exchange token", details: "Token exchange failed", status: :bad_request)
      return
    end

    user_info = GoogleOauth::Client.get_user_info(token_response["access_token"])

    unless user_info && user_info["email"].present?
      render_error(message: "Failed to get user info", details: "Could not retrieve email from Google", status: :bad_request)
      return
    end

    user = User.find_or_initialize_by(email: user_info["email"])

    user.name = user_info["name"] if user.new_record?
    user.tokens = {
      "access_token" => token_response["access_token"],
      "refresh_token" => token_response["refresh_token"]
    }
    user.save!

    if state[:return_url].present?
      redirect_to state[:return_url], allow_other_host: true
    else
      render_success(data: { message: "OAuth token stored successfully" }, status: :ok)
    end
  rescue StandardError => e
    render_error(message: e.message, details: "OAuth callback failed", status: :bad_request)
  end
end
