# frozen_string_literal: true

class UsersController < ApplicationController
  include Authenticatable
  include Authorizable

  before_action -> { authorize_current_user(:read) }, only: [:me]
  before_action -> { load_and_authorize_resource(User, :read, :id) }, only: [:show]

  def me
    serialized_data = UserSerializer.new(current_user).serializable_hash[:data][:attributes]
    render_success(data: serialized_data)
  end

  def show
    serialized_data = UserSerializer.new(@user).serializable_hash[:data][:attributes]
    render_success(data: serialized_data)
  end
end
