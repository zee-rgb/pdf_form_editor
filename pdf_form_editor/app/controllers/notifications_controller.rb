# frozen_string_literal: true

class NotificationsController < ApplicationController
  # Skip authentication for notifications
  skip_before_action :authenticate_user!, only: [ :create ]

  def create
    # Get message and type from params
    message = params[:message]
    type = params[:type] || "info"

    # Validate type to prevent XSS
    type = "info" unless %w[success error warning info].include?(type)

    respond_to do |format|
      format.turbo_stream do
        # Render a Turbo Stream that adds the notification to the container
        render turbo_stream: turbo_stream.append(
          "notification-container",
          partial: "shared/notification",
          locals: { message: message, type: type }
        )
      end

      format.json do
        render json: { status: "success" }
      end
    end
  end
end
