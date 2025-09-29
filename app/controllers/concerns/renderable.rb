module Renderable
  extend ActiveSupport::Concern

  private

  def render_success(data: nil, status: :ok)
    payload = {}
    payload[:data] = data if data
    render json: payload, status: status
  end

  def render_error(message:, details: nil, status: :bad_request)
    error_obj = { message: message }
    error_obj[:details] = details if details
    render json: { errors: [error_obj] }, status: status
  end

  def render_errors(messages:, status: :unprocessable_entity)
    errors_array = Array(messages).map { |msg| { message: msg } }
    render json: { errors: errors_array }, status: status
  end
end
