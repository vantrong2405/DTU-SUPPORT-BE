# frozen_string_literal: true

class Oauth::GoogleController < ApplicationController
  def redirect
    render_error(message: I18n.t("errors.invalid_oauth_redirect"), details: I18n.t("errors.missing_return_url"), status: :bad_request) and return if params[:return_url].blank?

    oauth_url = GoogleOauth::Client.generate_auth_url(base_url: request.base_url, return_url: params[:return_url])
    redirect_to oauth_url, allow_other_host: true
  rescue StandardError => e
    render_error(message: e.message, details: I18n.t("errors.failed_to_generate_oauth_url"), status: :bad_request)
  end

  def callback
    state = GoogleOauth::Client.decode_state(oauth_callback_params[:state])
    render_error(message: I18n.t("errors.oauth_error"), details: oauth_callback_params[:error], status: :bad_request) and return if oauth_callback_params[:error].present?

    complete_google_sign_in!(code: oauth_callback_params[:code], redirect_uri: state[:redirect_uri])

    redirect_to state[:return_url], allow_other_host: true
  rescue StandardError => e
    render_error(message: e.message, details: I18n.t("errors.oauth_callback_failed"), status: :bad_request)
  end

  def logout
    user_id = session[:user_id]
    Auth::SessionStore.new(session:, user_id:).clear_session if user_id.present?
    render_success(data: { message: I18n.t("errors.logged_out_successfully") })
  rescue StandardError => e
    render_error(message: e.message, details: I18n.t("errors.failed_to_logout"), status: :bad_request)
  end

  private

  def oauth_callback_params
    params.permit(:code, :state, :error)
  end

  def exchange_tokens(code, redirect_uri)
    GoogleOauth::Client.exchange_code_for_token(code:, redirect_uri:)
  end

  def upsert_user_from_oauth(user_info, token_response)
    user = User.find_or_initialize_by(email: user_info["email"])
    user.name = user_info["name"] if user.new_record?
    user.tokens = {
      "access_token"  => token_response["access_token"],
      "refresh_token" => token_response["refresh_token"],
    }
    user.save!
    user
  end

  def complete_google_sign_in!(code:, redirect_uri:)
    token_resp = exchange_tokens(code, redirect_uri)
    user_info = GoogleOauth::Client.get_user_info(token_resp["access_token"])
    user = upsert_user_from_oauth(user_info, token_resp)
    session[:user_id] = user.id
    Auth::SessionStore.new(session:, user_id: user.id).store_session(
      access_token:  token_resp["access_token"],
      refresh_token: token_resp["refresh_token"],
    )
    user
  end
end
