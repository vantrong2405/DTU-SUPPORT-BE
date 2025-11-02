# frozen_string_literal: true

class GoogleOauth::Client
  def self.generate_auth_url(base_url:, return_url: nil)
    redirect_uri = "#{base_url}/oauth/google/callback"

    state_data = {
      base_url: base_url,
      return_url: return_url
    }

    oauth_params = {
      response_type: "code",
      client_id: Rails.application.secrets.google_oauth[:client_id],
      redirect_uri: redirect_uri,
      scope: Rails.application.secrets.google_oauth[:scope],
      access_type: "offline",
      prompt: "select_account consent",
      state: Base64.urlsafe_encode64(state_data.to_json)
    }

    auth_uri = Rails.application.secrets.google_oauth[:auth_uri]
    "#{auth_uri}?#{oauth_params.map { |k, v| "#{k}=#{CGI.escape(v.to_s)}" }.join('&')}"
  end

  def self.exchange_code_for_token(code:, redirect_uri:)
    uri = URI(Rails.application.secrets.google_oauth[:token_uri])

    params = {
      code: code,
      client_id: Rails.application.secrets.google_oauth[:client_id],
      client_secret: Rails.application.secrets.google_oauth[:client_secret],
      redirect_uri: redirect_uri,
      grant_type: "authorization_code"
    }

    response = faraday_connection.post(uri, params)

    if response.success?
      JSON.parse(response.body)
    end
  rescue Faraday::Error => e
    Rails.logger.error "GoogleOauth: Network error during token exchange #{e.class}: #{e.message}\n#{e.backtrace&.join("\n")}"
    nil
  end

  def self.decode_state(encoded_state)
    JSON.parse(Base64.urlsafe_decode64(encoded_state)).with_indifferent_access if encoded_state.present?
  end

  def self.refresh_access_token!(refresh_token)
    raise StandardError, "No refresh token provided" if refresh_token.blank?

    uri = URI(Rails.application.secrets.google_oauth[:token_uri])

    params = {
      client_id: Rails.application.secrets.google_oauth[:client_id],
      client_secret: Rails.application.secrets.google_oauth[:client_secret],
      refresh_token: refresh_token,
      grant_type: "refresh_token"
    }

    response = faraday_connection.post(uri, params)

    if response.success?
      JSON.parse(response.body)
    else
      raise StandardError, "Failed to refresh token"
    end
  rescue Faraday::Error => e
    Rails.logger.error "GoogleOauth: Network error during token refresh: #{e.class}: #{e.message}\n#{e.backtrace&.join("\n")}"
    raise StandardError, "Failed to refresh token"
  end

  def self.token_expired?(access_token)
    uri = "#{Rails.application.secrets.google_oauth[:token_info_uri]}?access_token=#{CGI.escape(access_token)}"

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

    if response.success?
      JSON.parse(response.body)
    else
      Rails.logger.error "GoogleOauth: Failed to fetch user info: #{response.status}"
      raise StandardError, "Failed to fetch user info"
    end
  rescue Faraday::Error => e
    Rails.logger.error "GoogleOauth: Network error during user info fetch: #{e.class}: #{e.message}\n#{e.backtrace&.join("\n")}"
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
end
