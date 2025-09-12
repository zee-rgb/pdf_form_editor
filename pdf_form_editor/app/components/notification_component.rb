# frozen_string_literal: true

class NotificationComponent < ViewComponent::Base
  def initialize(message:, type: "info", auto_hide: true, duration: 3000)
    @message = message
    @type = type
    @auto_hide = auto_hide
    @duration = duration
  end

  def html_message?
    @message.to_s.include?("<") && @message.to_s.include?(">")
  end

  def safe_message
    html_message? ? @message.html_safe : @message
  end
end
