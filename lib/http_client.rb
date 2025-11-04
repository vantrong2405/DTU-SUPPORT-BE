# frozen_string_literal: true

require "net/http"
require "json"

module HttpClient
  module_function

  def get_json(url, headers: {})
    request_json(method: :get, url:, headers:)
  end

  def post_json(url, headers: {}, body: nil)
    request_json(method: :post, url:, headers:, body:)
  end

  def put_json(url, headers: {}, body: nil)
    request_json(method: :put, url:, headers:, body:)
  end

  def patch_json(url, headers: {}, body: nil)
    request_json(method: :patch, url:, headers:, body:)
  end

  def delete_json(url, headers: {})
    request_json(method: :delete, url:, headers:)
  end

  def request_json(method:, url:, headers: {}, body: nil)
    uri = URI(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == "https")

    req = build_request(method, uri)
    apply_headers(req, headers)
    apply_body(req, body) if body

    http.request(req)
  end

  def build_request(method, uri)
    case method.to_s.downcase.to_sym
    when :get then Net::HTTP::Get.new(uri.request_uri)
    when :post then Net::HTTP::Post.new(uri.request_uri)
    when :put then Net::HTTP::Put.new(uri.request_uri)
    when :patch then Net::HTTP::Patch.new(uri.request_uri)
    when :delete then Net::HTTP::Delete.new(uri.request_uri)
    else
      raise ArgumentError, "Unsupported method: #{method}"
    end
  end
  private_class_method :build_request

  def apply_headers(req, headers)
    default_headers = { "Content-Type" => "application/json" }
    default_headers.merge(headers || {}).each { |k, v| req[k] = v }
  end
  private_class_method :apply_headers

  def apply_body(req, body)
    req.body = body.is_a?(String) ? body : body.to_json
  end
  private_class_method :apply_body
end
