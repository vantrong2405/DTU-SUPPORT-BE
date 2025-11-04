# frozen_string_literal: true

class UsersController < ApplicationController
  include Authenticatable
  include Authorizable

  before_action :authenticate_user!, only: [:me, :show, :logout]
  before_action -> { authorize_current_user(:read) }, only: [:me]
  before_action -> { load_and_authorize_resource(User, :read, :id) }, only: [:show]

  def me
    render json: UserSerializer.new(current_user).serializable_hash, status: :ok
  end

  def show
    render json: UserSerializer.new(@user).serializable_hash, status: :ok
  end

  def logout
    Auth::SessionStore.new(session: session, user_id: current_user.id).remove_tokens
    session.delete(:user_id)
    render_success(data: { message: "Logged out successfully" })
  rescue StandardError => e
    render_error(message: e.message, details: "Failed to logout", status: :bad_request)
  end
end
