class ApplicationController < ActionController::Base
  include Pundit::Authorization

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Do not require auth for Devise and internal Rails controllers
  before_action :authenticate_user!, unless: :devise_controller?
  # Use wrappers instead of only:/except: to avoid Rails 7.1 missing-action errors
  after_action :pundit_verify_authorized, unless: :skip_pundit?
  after_action :pundit_verify_policy_scope, unless: :skip_pundit?

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  private

  def user_not_authorized
    flash[:alert] = "You are not authorized to perform this action."
    redirect_back(fallback_location: root_path)
  end

  # Skip Pundit on Devise and Rails internal controllers
  def skip_pundit?
    devise_controller? || params[:controller] =~ /(rails\/|active_storage\/)/
  end

  # Wrapper that mirrors `except: :index` without triggering missing-action checks
  def pundit_verify_authorized
    return if action_name == "index"
    verify_authorized
  end

  # Wrapper that mirrors `only: :index` without triggering missing-action checks
  def pundit_verify_policy_scope
    return unless action_name == "index"
    verify_policy_scoped
  end
end
