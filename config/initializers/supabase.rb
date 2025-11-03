# frozen_string_literal: true

require "net/http"

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

  def patch(table, id, data: {})
    execute_request(:patch, "#{table}?id=eq.#{id}", body: data)
  end

  def delete(table, id)
    execute_request(:delete, "#{table}?id=eq.#{id}")
  end

  private

  def execute_request(method, path, body: nil, query: nil)
    uri = URI("#{@url}/#{path}")
    uri.query = URI.encode_www_form(query) if query

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"

    request_class = case method
                    when :get then Net::HTTP::Get
                    when :post then Net::HTTP::Post
                    when :patch then Net::HTTP::Patch
                    when :delete then Net::HTTP::Delete
                    end

    request = request_class.new(uri.request_uri)
    @headers.each { |k, v| request[k] = v }
    request.body = body.to_json if body

    response = http.request(request)
    handle_response(response)
  end

  def handle_response(response)
    case response.code.to_i
    when 200..299
      JSON.parse(response.body) rescue response.body
    when 400
      raise Supabase::BadRequestError, response.body
    when 401
      raise Supabase::UnauthorizedError, response.body
    when 404
      raise Supabase::NotFoundError, response.body
    else
      raise Supabase::ApiError, "HTTP #{response.code}: #{response.body}"
    end
  end

  class ApiError < StandardError; end
  class BadRequestError < ApiError; end
  class UnauthorizedError < ApiError; end
  class NotFoundError < ApiError; end
end
