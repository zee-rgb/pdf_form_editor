import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="notification"
export default class extends Controller {
  static targets = ["container"]
  static values = { 
    position: { type: String, default: "top-right" }
  }

  connect() {
    // Make the showNotification function available globally
    window.showNotification = this.showNotification.bind(this)
  }
  
  /**
   * Create and display a notification
   * @param {string} message - Message to display
   * @param {string} type - Type of notification (success, error, warning, info)
   * @returns {void}
   */
  showNotification(message, type = "info") {
    // Make a fetch request to create a notification component
    fetch("/notifications/create", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Accept": "text/vnd.turbo-stream.html",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.getAttribute("content")
      },
      body: JSON.stringify({ message, type })
    })
    .then(response => {
      if (!response.ok) throw new Error("Failed to create notification")
      return response.text()
    })
    .then(html => {
      // Insert the Turbo stream content
      Turbo.renderStreamMessage(html)
    })
    .catch(error => {
      console.error("Error showing notification:", error)
      
      // Fallback to legacy notification system
      this.createLegacyNotification(message, type)
    })
  }
  
  /**
   * Legacy notification system as fallback
   * @private
   */
  createLegacyNotification(message, type) {
    // Find or create container
    let container = document.getElementById("notification-container")
    if (!container) {
      container = document.createElement("div")
      container.id = "notification-container"
      container.style.position = "fixed"
      container.style.top = "20px"
      container.style.right = "20px"
      container.style.zIndex = "9999"
      document.body.appendChild(container)
    }
    
    // Create notification element
    const notification = document.createElement("div")
    notification.className = `notification notification-${type}`
    notification.style.padding = "12px 16px"
    notification.style.margin = "0 0 10px 0"
    notification.style.borderRadius = "4px"
    notification.style.boxShadow = "0 2px 5px rgba(0,0,0,0.2)"
    notification.style.fontWeight = "500"
    notification.style.opacity = "0"
    notification.style.transform = "translateX(40px)"
    notification.style.transition = "opacity 0.3s, transform 0.3s"
    
    // Set color based on type
    if (type === "success") {
      notification.style.backgroundColor = "#10B981"
      notification.style.color = "white"
    } else if (type === "error") {
      notification.style.backgroundColor = "#EF4444"
      notification.style.color = "white"
    } else if (type === "warning") {
      notification.style.backgroundColor = "#F59E0B"
      notification.style.color = "white"
    } else {
      notification.style.backgroundColor = "#3B82F6"
      notification.style.color = "white"
    }
    
    notification.textContent = message
    container.appendChild(notification)
    
    // Animate in
    setTimeout(() => {
      notification.style.opacity = "1"
      notification.style.transform = "translateX(0)"
    }, 10)
    
    // Remove after delay
    setTimeout(() => {
      notification.style.opacity = "0"
      notification.style.transform = "translateX(40px)"
      
      setTimeout(() => {
        if (container.contains(notification)) {
          container.removeChild(notification)
        }
      }, 300)
    }, 3000)
  }
}
