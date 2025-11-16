# frozen_string_literal: true

class UsersController < ApplicationController
  include Authenticatable
  include Authorizable

  before_action :authenticate_user!, only: %i[me show]
  before_action -> { authorize_current_user(:read) }, only: [:me]
  before_action -> { load_and_authorize_resource(User, :read, :id) }, only: [:show]

  def me
    render json: UserSerializer.new(current_user).serializable_hash, status: :ok
  end

  def show
    render json: UserSerializer.new(@user).serializable_hash, status: :ok
  end
end
