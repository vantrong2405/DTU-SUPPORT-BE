# frozen_string_literal: true

require "net/http"
require "openssl"
require "base64"
require "uri"

class Senpay::Client < BaseService
  # rubocop:disable Lint/MissingSuper
  def initialize
    senpay_config = Rails.application.config.senpay
    @merchant_id = senpay_config[:merchant_id]
    @secret_key = senpay_config[:secret_key]
    @api_url = senpay_config[:api_url]
    @checkout_url = senpay_config[:checkout_url]
  end
  # rubocop:enable Lint/MissingSuper

  def build_signature(params)
    normalized_params = normalize_params(params)
    normalized_params.delete(:signature)

    sorted_params = normalized_params.sort.to_h
    signature_string = sorted_params.map { |k, v| "#{k}=#{v}" }.join("&")
    hmac = OpenSSL::HMAC.digest("SHA256", @secret_key, signature_string)
    Base64.strict_encode64(hmac)
  end

  def create_payment_request(params)
    form_params = build_form_params(params)
    signature = build_signature(form_params)
    form_params[:signature] = signature

    # Log form params (mask signature) for debugging
    log_params = form_params.dup
    log_params[:signature] = "[MASKED]" if log_params[:signature]
    Rails.logger.info("SenPay create_payment_request form_params: #{log_params.to_json}")
    Rails.logger.debug("SenPay signature: #{signature}")
    Rails.logger.debug("SenPay signature string: #{build_signature_string(form_params)}")

    {
      checkout_url: @checkout_url,
      form_data: form_params,
    }
  end

  def build_signature_string(params)
    normalized_params = normalize_params(params)
    normalized_params.delete(:signature)
    sorted_params = normalized_params.sort.to_h
    sorted_params.map { |k, v| "#{k}=#{v}" }.join("&")
  end

  def init_checkout(params)
    body_params = build_checkout_params(params)
    signature = build_signature(body_params)
    body_params[:signature] = signature

    uri = URI(@checkout_url)
    http = setup_http_client(uri)
    request = build_post_request(uri, body_params)

    # Log request (mask signature)
    log_params = body_params.dup
    log_params[:signature] = "[MASKED]" if log_params[:signature]
    Rails.logger.info("SenPay init_checkout request: #{log_params.to_json}")
    Rails.logger.debug("SenPay signature: #{signature}")

    response = execute_request_with_retry(http, request)
    parse_checkout_response(response)
  rescue StandardError => e
    Rails.logger.error("SenPay init_checkout failed: #{e.class} - #{e.message}")
    Rails.logger.error(e.backtrace.join("\n")) if e.backtrace
    { success: false, error: e.message }
  end

  def verify_webhook_signature(params, signature)
    return false if signature.blank? || @secret_key.blank?

    expected_signature = build_signature(params)
    ActiveSupport::SecurityUtils.secure_compare(expected_signature, signature)
  end

  def query_order_status(order_id)
    uri = URI("#{@api_url}/v1/order/detail/#{order_id}")
    http = setup_http_client(uri)
    request = build_get_request(uri)

    response = execute_request_with_retry(http, request)
    parse_order_response(response)
  rescue StandardError => e
    Rails.logger.error("SenPay API query failed: #{e.class} - #{e.message}")
    { success: false, error: e.message }
  end

  private

  def normalize_params(params)
    params.with_indifferent_access
  end

  def build_form_params(params)
    normalized = normalize_params(params)
    {
      merchant: @merchant_id,
      order_amount: normalized[:order_amount],
      order_invoice_number: normalized[:order_invoice_number],
      order_description: normalized[:order_description] || "",
      return_url: normalized[:return_url],
      ipn_url: normalized[:ipn_url],
    }.compact
  end

  def build_checkout_params(params)
    normalized = normalize_params(params)
    {
      merchant: @merchant_id,
      order_amount: normalized[:order_amount],
      order_invoice_number: normalized[:order_invoice_number],
      order_description: normalized[:order_description] || "",
      return_url: normalized[:return_url],
      ipn_url: normalized[:ipn_url],
    }.compact
  end

  def setup_http_client(uri)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 30
    http.open_timeout = 10
    http
  end

  def build_get_request(uri)
    request = Net::HTTP::Get.new(uri.path)
    request["Authorization"] = build_auth_header
    request["Content-Type"] = "application/json"
    request
  end

  def build_post_request(uri, body_params)
    request = Net::HTTP::Post.new(uri.path)
    request["Content-Type"] = "application/x-www-form-urlencoded"
    request["Accept"] = "application/json"

    # Convert params to form data format
    form_data = body_params.map { |k, v| "#{URI.encode_www_form_component(k.to_s)}=#{URI.encode_www_form_component(v.to_s)}" }.join("&")
    request.body = form_data
    request
  end

  def build_auth_header
    credentials = "#{@merchant_id}:#{@secret_key}"
    encoded = Base64.strict_encode64(credentials)
    "Basic #{encoded}"
  end

  def execute_request_with_retry(http, request, retries: 3)
    attempt = 0
    begin
      attempt += 1
      http.request(request)
    rescue Net::TimeoutError, Net::OpenTimeout, Errno::ECONNREFUSED, Errno::ETIMEDOUT => e
      handle_retry(e, attempt, retries) && retry
    rescue StandardError => e
      Rails.logger.error("SenPay API request failed: #{e.class} - #{e.message}")
      raise
    end
  end

  def handle_retry(error, attempt, retries)
    if attempt < retries
      sleep_time = 2**attempt
      Rails.logger.warn("SenPay API request failed (attempt #{attempt}/#{retries}): #{error.class} - #{error.message}. Retrying in #{sleep_time}s...")
      sleep(sleep_time)
    else
      Rails.logger.error("SenPay API request failed after #{retries} attempts: #{error.class} - #{error.message}")
      raise
    end
  end

  def parse_order_response(response)
    return { success: false, error: "HTTP #{response.code}" } unless response.code.to_i == 200

    body = JSON.parse(response.body)
    return { success: false, error: body["message"] || "Unknown error" } unless body["success"]

    {
      success: true,
      order_invoice_number: body.dig("data", "order_invoice_number"),
      order_amount: body.dig("data", "order_amount"),
      order_status: body.dig("data", "order_status"),
      transaction_id: body.dig("data", "transaction_id"),
    }
  rescue JSON::ParserError => e
    Rails.logger.error("SenPay API response parse error: #{e.message}")
    { success: false, error: "Invalid response format" }
  end

  def parse_checkout_response(response)
    Rails.logger.info("SenPay init_checkout response code: #{response.code}")
    Rails.logger.debug("SenPay init_checkout response body: #{response.body}")

    case response.code.to_i
    when 200, 201, 302
      # SePay có thể redirect (302) hoặc trả về JSON (200)
      # Nếu là redirect, lấy Location header
      if response.code.to_i == 302
        redirect_url = response["Location"]
        if redirect_url.present?
          {
            success: true,
            checkout_url: redirect_url,
          }
        else
          { success: false, error: "Redirect URL not found in response" }
        end
      else
        # Try parse JSON response
        begin
          body = JSON.parse(response.body)
          if body["success"] || body["checkout_url"] || body["redirect_url"]
            {
              success: true,
              checkout_url: body["checkout_url"] || body["redirect_url"] || body.dig("data", "checkout_url"),
              transaction_id: body["transaction_id"] || body.dig("data", "transaction_id"),
              order_invoice_number: body["order_invoice_number"] || body.dig("data", "order_invoice_number"),
            }
          else
            { success: false, error: body["message"] || "Unknown error", response_body: body }
          end
        rescue JSON::ParserError
          # Response không phải JSON, có thể là HTML redirect page
          # Extract redirect URL từ HTML hoặc Location header
          redirect_url = response["Location"] || extract_redirect_from_html(response.body)
          if redirect_url.present?
            {
              success: true,
              checkout_url: redirect_url,
            }
          else
            { success: false, error: "Cannot parse response", response_body: response.body[0..500] }
          end
        end
      end
    when 403
      error_body = begin
        JSON.parse(response.body)
      rescue JSON::ParserError
        { message: response.body[0..500] }
      end
      Rails.logger.error("SenPay init_checkout 403 Forbidden: #{error_body}")
      { success: false, error: "Forbidden", details: error_body["message"] || error_body.to_s, response_body: error_body }
    when 400, 422
      error_body = begin
        JSON.parse(response.body)
      rescue JSON::ParserError
        { message: response.body[0..500] }
      end
      { success: false, error: error_body["message"] || "Bad request", response_body: error_body }
    else
      { success: false, error: "HTTP #{response.code}", response_body: response.body[0..500] }
    end
  rescue StandardError => e
    Rails.logger.error("SenPay init_checkout response parse error: #{e.class} - #{e.message}")
    { success: false, error: "Invalid response format", response_body: response.body[0..500] }
  end

  def extract_redirect_from_html(html_body)
    # Try to extract redirect URL from HTML meta refresh or JavaScript redirect
    if html_body.present?
      # Look for meta refresh
      if html_body =~ /<meta[^>]*http-equiv=["']refresh["'][^>]*content=["'][^"]*url=([^"']+)/i
        return $1
      end
      # Look for window.location
      if html_body =~ /window\.location\s*=\s*["']([^"']+)/i
        return $1
      end
    end
    nil
  end
end
