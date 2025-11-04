# frozen_string_literal: true

require "net/http"
require_relative "http_client"

class Gemini
  DEFAULT_TEMPERATURE = 0.0
  DEFAULT_TOP_P = 1.0
  DEFAULT_TOP_K = 1

  def initialize(api_key: nil)
    @api_key = api_key || ENV.fetch("GEMINI_API_KEY", nil)
  end

  # rubocop:disable Metrics/MethodLength
  def generate_content(**opts)
    uri = build_endpoint_uri(model: opts.fetch(:model, Rails.configuration.x.gemini[:default_model]))
    contents = build_contents(history: opts.fetch(:history, []), prompt: opts[:prompt], function_response: opts[:function_response])
    request_body = build_request_body(
      contents:,
      system_instruction: opts[:system_instruction],
      temperature:        opts.fetch(:temperature, DEFAULT_TEMPERATURE),
      top_p:              opts.fetch(:top_p, DEFAULT_TOP_P),
      top_k:              opts.fetch(:top_k, DEFAULT_TOP_K),
      tools:              opts[:tools],
    )
    handle_response(
      HttpClient.post_json(
        uri.to_s,
        headers: { "x-goog-api-key" => @api_key },
        body:    request_body,
      ),
    )
  end
  # rubocop:enable Metrics/MethodLength

  private

  def handle_response(response)
    code = response.code.to_i
    return extract_text_from_response(JSON.parse(response.body)) if (200..299).cover?(code)

    raise error_for_code(code), (code >= 500 ? "HTTP #{code}: #{response.body}" : response.body)
  end

  def extract_text_from_response(response)
    candidates = response["candidates"]
    return empty_extraction(response) if candidates.blank?

    extract_from_candidate(candidates.first, response)
  end

  def extract_function_call(function_call)
    { name: function_call["name"], args: function_call["args"] || {} }
  end

  def build_endpoint_uri(model:)
    URI("#{Rails.configuration.x.gemini[:api_base_url]}/models/#{model}:generateContent")
  end

  def build_contents(history:, prompt:, function_response: nil)
    contents = history.dup
    if function_response
      contents << { role: "model", parts: [{ functionCall: function_response[:function_call] }] }
      contents << { role:  "function",
                    parts: [{ functionResponse: { name: function_response[:name], response: function_response[:response] } }], }
    else
      contents << { role: "user", parts: [{ text: prompt }] }
    end
    contents
  end

  def build_request_body(config)
    body = {
      contents:         config[:contents],
      generationConfig: { temperature: config[:temperature], topP: config[:top_p], topK: config[:top_k] },
    }
    if config[:system_instruction].present?
      body[:systemInstruction] = { parts: [{ text: config[:system_instruction] }] }
    end
    body[:tools] = config[:tools] if config[:tools].present?
    body
  end

  def error_for_code(code)
    case code
    when 400 then Gemini::BadRequestError
    when 401 then Gemini::UnauthorizedError
    when 403 then Gemini::ForbiddenError
    when 429 then Gemini::RateLimitError
    when 500..599 then Gemini::ServerError
    else Gemini::ApiError
    end
  end

  def empty_extraction(response)
    { text: nil, function_call: nil, candidates: [], usage_metadata: nil, full_response: response }
  end

  def extract_from_candidate(candidate, full_response)
    parts = candidate&.dig("content", "parts") || []
    text_part = parts.find { |p| p["text"].present? }
    function_call_part = parts.find { |p| p["functionCall"].present? }
    {
      text:           text_part&.dig("text"),
      function_call:  function_call_part ? extract_function_call(function_call_part["functionCall"]) : nil,
      candidates:     [candidate],
      usage_metadata: full_response["usageMetadata"],
      full_response:,
    }
  end

  class ApiError < StandardError; end
  class BadRequestError < ApiError; end
  class UnauthorizedError < ApiError; end
  class ForbiddenError < ApiError; end
  class RateLimitError < ApiError; end
  class ServerError < ApiError; end
end
