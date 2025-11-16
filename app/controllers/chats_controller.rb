# frozen_string_literal: true

class ChatsController < ApplicationController
  include Authenticatable

  before_action :authenticate_user!, only: [:create]
  before_action :load_chat_params, only: [:create]

  def create
    result = Chats::ProcessMessageService.call(messages: @messages, tone: @tone)
    if result[:success]
      render_success(data: { content: result[:content], toolResult: result[:tool_result], metadata: result[:metadata] }.compact)
    else
      render_error(message: I18n.t("errors.failed_to_process_message"), details: result[:error], status: :internal_server_error)
    end
  rescue ActionController::ParameterMissing => e
    render_error(message: I18n.t("errors.parameter_missing"), details: e.message, status: :bad_request)
  rescue StandardError => e
    render_error(message: I18n.t("errors.internal_server_error"), details: e.message, status: :internal_server_error)
  end

  private

  def load_chat_params
    @messages = params.require(:messages)
    @tone = params[:tone]
  end
end
