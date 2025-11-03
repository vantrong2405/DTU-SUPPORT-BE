# frozen_string_literal: true

module Authorizable
  extend ActiveSupport::Concern

  private

  def authorize_resource(resource, action = :read)
    authorize! action, resource
  end

  def load_and_authorize_resource(model_class, action = :read, param_key = :id)
    resource = model_class.find(params[param_key])
    authorize! action, resource
    instance_variable_set("@#{model_class.name.underscore}", resource)
  end

  def authorize_current_user(action = :read)
    authorize! action, current_user
  end
end
