# frozen_string_literal: true

class RegistrationFilterPolicy < ApplicationPolicy
  def index?
    staff?
  end

  def create?
    admin?
  end

  def destroy?
    admin?
  end

  def update?
    admin?
  end
end
