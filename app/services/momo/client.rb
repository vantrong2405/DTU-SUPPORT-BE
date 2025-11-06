# frozen_string_literal: true

require "net/http"
require "openssl"
require "securerandom"
require "json"

class Momo::Client < BaseService
  # rubocop:disable Lint/MissingSuper
  def initialize
    @partner_code = ENV.fetch("MOMO_PARTNER_CODE")
    @access_key = ENV.fetch("MOMO_ACCESS_KEY")
    @secret_key = ENV.fetch("MOMO_SECRET_KEY")
    @api_url = ENV.fetch("MOMO_API_URL")
  end
  # rubocop:enable Lint/MissingSuper

  def create_payment_request(payment_options = {})
    payment_options = { order_id: payment_options[:order_id], amount: payment_options[:amount], order_info: payment_options[:order_info],
redirect_url: payment_options[:redirect_url], ipn_url: payment_options[:ipn_url], extra_data: payment_options[:extra_data] || "", }
    request_id = SecureRandom.uuid
    raw_signature = build_payment_signature(request_id:, payment_options:)
    signature = build_signature(raw_signature)
    request_body = build_payment_request_body(request_id:, signature:, payment_options:)
    response = send_request(request_body)
    parse_response(response)
  end

  def verify_webhook_signature(params)
    signature = params.delete("signature") || params.delete(:signature)
    return false if signature.blank?

    raw_signature = build_signature_string_from_webhook(params)
    expected_signature = build_signature(raw_signature)
    ActiveSupport::SecurityUtils.secure_compare(expected_signature, signature)
  end

  private

  def build_payment_signature(request_id:, payment_options:)
    params = build_signature_params(request_id:, payment_options:)
    build_signature_string(params)
  end

  def build_signature_params(request_id:, payment_options:)
    {
      access_key: @access_key, amount: payment_options[:amount],
      extra_data: payment_options[:extra_data], ipn_url: payment_options[:ipn_url],
      order_id: payment_options[:order_id], order_info: payment_options[:order_info],
      partner_code: @partner_code, redirect_url: payment_options[:redirect_url], request_id:,
    }
  end

  def build_signature_string(params)
    sorted = params.sort.to_h
    sorted.map { |k, v| "#{k}=#{v}" }.join("&")
  end

  def build_payment_request_body(request_id:, signature:, payment_options:)
    {
      partnerCode: @partner_code, partnerName: ENV.fetch("MOMO_PARTNER_NAME"),
      storeId: ENV.fetch("MOMO_STORE_ID", nil), requestId: request_id,
      amount: payment_options[:amount], orderId: payment_options[:order_id],
      orderInfo: payment_options[:order_info], redirectUrl: payment_options[:redirect_url],
      ipnUrl: payment_options[:ipn_url], requestType: "captureWallet",
      extraData: payment_options[:extra_data], signature:,
    }
  end

  def build_signature_string_from_webhook(params)
    sorted_params = params.sort.to_h
    sorted_params.map { |k, v| "#{k}=#{v}" }.join("&")
  end

  def build_signature(raw_signature)
    OpenSSL::HMAC.hexdigest("SHA256", @secret_key, raw_signature)
  end

  def send_request(request_body, retries: 3)
    http = setup_http_client
    request = build_http_request(request_body)
    execute_request_with_retry(http, request, retries)
  end

  def execute_request_with_retry(http, request, retries)
    attempt = 0
    begin
      attempt += 1
      http.request(request)
    rescue Net::TimeoutError, Net::OpenTimeout, Errno::ECONNREFUSED, Errno::ETIMEDOUT => e
      handle_retry(e, attempt, retries) && retry
    rescue StandardError => e
      handle_error(e) && raise
    end
  end

  def handle_error(error)
    Rails.logger.error("MoMo API request failed: #{error.class} - #{error.message}")
  end

  def setup_http_client
    uri = URI(@api_url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 30
    http.open_timeout = 10
    http
  end

  def build_http_request(request_body)
    uri = URI(@api_url)
    request = Net::HTTP::Post.new(uri.path)
    request["Content-Type"] = "application/json"
    request.body = request_body.to_json
    request
  end

  def handle_retry(error, attempt, retries)
    if attempt < retries
      sleep_time = 2**attempt
      Rails.logger.warn("MoMo API request failed (attempt #{attempt}/#{retries}): #{error.class} - #{error.message}. Retrying in #{sleep_time}s...")
      sleep(sleep_time)
    else
      Rails.logger.error("MoMo API request failed after #{retries} attempts: #{error.class} - #{error.message}")
      raise
    end
  end

  def parse_response(response)
    return { success: false, error: "HTTP #{response.code}" } unless response.code.to_i == 200

    body = JSON.parse(response.body)
    return { success: false, error: body["message"] || "Unknown error" } unless body["resultCode"] == 0

    build_success_response(body)
  rescue JSON::ParserError => e
    Rails.logger.error("MoMo API response parse error: #{e.message}")
    { success: false, error: "Invalid response format" }
  end

  def build_success_response(body)
    {
      success: true, pay_url: body["payUrl"], request_id: body["requestId"],
      order_id: body["orderId"], amount: body["amount"],
      response_time: body["responseTime"], message: body["message"],
    }
  end
end
