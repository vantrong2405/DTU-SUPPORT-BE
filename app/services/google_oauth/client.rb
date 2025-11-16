# frozen_string_literal: true

class GoogleOauth::Client
  def self.generate_auth_url(base_url:, return_url: nil)
    redirect_uri = "#{base_url}/oauth/google/callback"
    state_data   = build_state_data(base_url:, redirect_uri:, return_url:)
    params       = build_auth_params(redirect_uri:, state_data:)
    auth_uri     = Rails.application.config.secrets.google_oauth[:auth_uri]
    "#{auth_uri}?#{params.map { |k, v| "#{k}=#{CGI.escape(v.to_s)}" }.join('&')}"
  end

  def self.exchange_code_for_token(code:, redirect_uri:)
    uri = URI(Rails.application.config.secrets.google_oauth[:token_uri])
    params = build_token_params(code:, redirect_uri:)
    response = faraday_connection.post(uri, params)
    return JSON.parse(response.body) if response.success?
    nil
  rescue Faraday::Error
    nil
  end

  def self.decode_state(encoded_state)
    JSON.parse(Base64.urlsafe_decode64(encoded_state)).with_indifferent_access if encoded_state.present?
  end

  def self.refresh_access_token!(refresh_token)
    raise StandardError, I18n.t("errors.no_refresh_token_provided") if refresh_token.blank?

    uri = URI(Rails.application.config.secrets.google_oauth[:token_uri])
    params = build_refresh_params(refresh_token:)
    response = faraday_connection.post(uri, params)
    return JSON.parse(response.body) if response.success?
    raise StandardError, I18n.t("errors.failed_to_refresh_token")
  rescue Faraday::Error
    raise StandardError, I18n.t("errors.failed_to_refresh_token")
  end

  def self.token_expired?(access_token)
    uri = "#{Rails.application.config.secrets.google_oauth[:token_info_uri]}?access_token=#{CGI.escape(access_token)}"

    response = faraday_connection.get(uri)

    !response.success?
  rescue Faraday::Error => e
    Rails.logger.error "GoogleOauth: Network error during token check: #{e.class}: #{e.message}\n#{e.backtrace&.join("\n")}"
    true
  end

  def self.get_user_info(access_token)
    uri = URI("https://www.googleapis.com/oauth2/v2/userinfo")

    response = faraday_connection.get(uri) do |req|
      req.headers["Authorization"] = "Bearer #{access_token}"
    end

    return JSON.parse(response.body) if response.success?
    raise StandardError, I18n.t("errors.failed_to_fetch_user_info")
  rescue Faraday::Error
    nil
  end

  def self.faraday_connection
    Faraday.new do |conn|
      conn.request :url_encoded
      conn.response :logger, Rails.logger, { headers: false, bodies: false }
      conn.adapter Faraday.default_adapter
      conn.options.timeout = 30
      conn.options.open_timeout = 10
    end
  end

  def self.build_state_data(base_url:, redirect_uri:, return_url:)
    { base_url:, redirect_uri:, return_url: }
  end

  def self.build_auth_params(redirect_uri:, state_data:)
    {
      response_type: "code",
      client_id:     Rails.application.config.secrets.google_oauth[:client_id],
      redirect_uri:,
      scope:         Rails.application.config.secrets.google_oauth[:scope],
      access_type:   "offline",
      prompt:        "select_account consent",
      state:         Base64.urlsafe_encode64(state_data.to_json),
    }
  end

  def self.build_token_params(code:, redirect_uri:)
    {
      code:,
      client_id:     Rails.application.config.secrets.google_oauth[:client_id],
      client_secret: Rails.application.config.secrets.google_oauth[:client_secret],
      redirect_uri:,
      grant_type:    "authorization_code",
    }
  end

  def self.build_refresh_params(refresh_token:)
    {
      client_id:     Rails.application.config.secrets.google_oauth[:client_id],
      client_secret: Rails.application.config.secrets.google_oauth[:client_secret],
      refresh_token:,
      grant_type:    "refresh_token",
    }
  end
end
