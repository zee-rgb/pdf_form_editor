# frozen_string_literal: true

class PdfDocumentPolicy < ApplicationPolicy
  def index?
    user.present?
  end

  def show?
    user.present? && record.user == user
  end

  def create?
    user.present?
  end

  def update?
    user.present? && record.user == user
  end

  def destroy?
    user.present? && record.user == user
  end

  def add_text?
    update?
  end

  def add_signature?
    update?
  end

  def download?
    show?
  end

  def embed_view?
    show?
  end

  def simple_edit?
    update?
  end

  def basic_view?
    update?
  end

  class Scope < Scope
    def resolve
      if user.present?
        scope.where(user: user)
      else
        scope.none
      end
    end
  end
end
