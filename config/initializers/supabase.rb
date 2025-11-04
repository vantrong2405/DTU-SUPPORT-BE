# frozen_string_literal: true

require "net/http"
require_relative "../../lib/http_client"

class Supabase
  def initialize
    @url = "#{Rails.application.config.secrets.supabase[:url]}/rest/v1"
    api_key = Rails.application.config.secrets.supabase[:key]

    @headers = {
      "apikey"        => api_key,
      "Authorization" => "Bearer #{api_key}",
      "Content-Type"  => "application/json",
      "Prefer"        => "return=representation",
    }
  end

  def get(table, filters: {})
    query = filters.any? ? filters : nil
    execute_request(:get, table, query:)
  end

  def post(table, data: {})
    execute_request(:post, table, body: data)
  end

  def patch(table, record_id, data: {})
    execute_request(:patch, "#{table}?id=eq.#{record_id}", body: data)
  end

  def delete(table, record_id)
    execute_request(:delete, "#{table}?id=eq.#{record_id}")
  end

  private

  def execute_request(method, path, body: nil, query: nil)
    uri = build_uri(path, query)
    response = HttpClient.request_json(method:, url: uri.to_s, headers: @headers, body:)
    handle_response(response)
  end

  def handle_response(response)
    code = response.code.to_i
    return JSON.parse(response.body) rescue response.body if (200..299).cover?(code)
    raise error_for_code(code), (code >= 400 ? response.body : "HTTP #{code}: #{response.body}")
  end

  def build_uri(path, query)
    uri = URI("#{@url}/#{path}")
    uri.query = URI.encode_www_form(query) if query
    uri
  end

  def error_for_code(code)
    return Supabase::ApiError if code >= 500
    { 400 => Supabase::BadRequestError, 401 => Supabase::UnauthorizedError, 404 => Supabase::NotFoundError }[code] || Supabase::ApiError
  end

  class ApiError < StandardError; end
  class BadRequestError < ApiError; end
  class UnauthorizedError < ApiError; end
  class NotFoundError < ApiError; end
end
