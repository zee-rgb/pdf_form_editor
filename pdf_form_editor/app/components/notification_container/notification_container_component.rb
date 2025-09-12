# frozen_string_literal: true

class NotificationContainer::NotificationContainerComponent < ViewComponent::Base
  renders_many :notifications, "NotificationComponent"

  def initialize(position: "top-right")
    @position = position

    # Convert position to CSS class
    @position_class = case @position
    when "top-right"
      "fixed top-5 right-5"
    when "top-left"
      "fixed top-5 left-5"
    when "bottom-right"
      "fixed bottom-5 right-5"
    when "bottom-left"
      "fixed bottom-5 left-5"
    else
      "fixed top-5 right-5" # Default to top right
    end
  end
end
