# frozen_string_literal: true

module NotificationHelper
  # Creates a notification using the NotificationComponent
  # @param message [String] The notification message
  # @param type [String] The notification type (success, error, warning, info)
  # @param auto_hide [Boolean] Whether to auto-hide the notification
  # @param duration [Integer] Duration in ms before auto-hiding
  def render_notification(message, type: "info", auto_hide: true, duration: 3000)
    render(NotificationComponent.new(
      message: message,
      type: type,
      auto_hide: auto_hide,
      duration: duration
    ))
  end

  # Helper to create JS-based notifications
  def notification_script(message, type: "info")
    # Escape single quotes in the message for JS
    escaped_message = message.to_s.gsub("'", "\\\\'")

    # Create JS to render notification
    javascript_tag <<~JS
      document.addEventListener('DOMContentLoaded', function() {
        if (typeof showNotification === 'function') {
          showNotification('#{escaped_message}', '#{type}');
        } else {
          console.log('Notification system not ready, message: #{escaped_message}, type: #{type}');
        }
      });
    JS
  end
end
