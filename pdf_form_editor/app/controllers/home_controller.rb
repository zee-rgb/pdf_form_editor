class HomeController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index]
  skip_after_action :verify_authorized, only: [:index]
  skip_after_action :verify_policy_scoped, only: [:index]
  
  def index
    # Landing page for non-authenticated users
    redirect_to pdf_documents_path if user_signed_in?
  end
end
