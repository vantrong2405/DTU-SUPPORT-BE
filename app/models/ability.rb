# frozen_string_literal: true

class Ability
  include CanCan::Ability

  def initialize(user)
    return unless user

    if admin?(user)
      can :read, User
      can :update, User, id: user.id
      can :destroy, User, id: user.id
    else
      can :read, User, id: user.id
      can :update, User, id: user.id
      can :destroy, User, id: user.id
    end
  end

  private

  def admin?(user)
    user.respond_to?(:admin?) && user.admin?
  end
end
