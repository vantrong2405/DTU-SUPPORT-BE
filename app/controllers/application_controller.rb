# frozen_string_literal: true

class ApplicationController < ActionController::API
  include Renderable
  include CanCan::ControllerAdditions

  rescue_from ActiveRecord::RecordNotFound do |e|
    render_error(message: "Not found", code: "record_not_found", details: e.message, status: :not_found)
  end

  rescue_from ActionController::ParameterMissing do |e|
    render_error(message: "Missing parameter", code: "parameter_missing", details: e.message, status: :bad_request)
  end

  rescue_from ActiveRecord::RecordInvalid do |e|
    render_errors(messages: e.record.errors.full_messages, code: "record_invalid", status: :unprocessable_entity)
  end

  rescue_from CanCan::AccessDenied do |e|
    render_error(message: "Forbidden", details: e.message, status: :forbidden)
  end

  private

  def current_ability
    @current_ability ||= Ability.new(current_user)
  end
end
