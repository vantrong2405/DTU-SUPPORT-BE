# frozen_string_literal: true

class UserSerializer < BaseSerializer
  attributes :id, :email, :name, :subscription_plan_id
end
