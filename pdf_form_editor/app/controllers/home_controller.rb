class HomeController < ApplicationController
  skip_before_action :authenticate_user!, only: :index
  # Match the wrapper callbacks defined in ApplicationController
  skip_after_action :pundit_verify_authorized, only: [ :index, :test_notifications ]
  skip_after_action :pundit_verify_policy_scope, only: [ :index, :test_notifications ]

  def index
    # Landing page for non-authenticated users
    redirect_to pdf_documents_path if user_signed_in?
  end

  # Test view for our notification components
  def test_notifications
    # This action just renders the test_notifications view
    flash.now[:notice] = "This is a flash notice message"
    flash.now[:alert] = "This is a flash alert message"
  end
end
