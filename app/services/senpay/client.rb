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

    {
      checkout_url: @checkout_url,
      form_data: form_params,
    }
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
end
