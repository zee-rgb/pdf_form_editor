import { Controller } from "@hotwired/stimulus"

/**
 * PDF Editor controller for handling PDF editing functionality using Hotwire/Turbo
 * 
 * This controller replaces direct JavaScript fetch calls with Turbo Stream submissions
 * for adding text, signatures, and other elements to PDFs
 */
export default class extends Controller {
  static targets = [
    "canvas", "clickOverlay", "textX", "textY", "signatureX", "signatureY", 
    "zoomLevel", "status", "textInput", "typedSig", "textForm", "signatureForm",
    "preview"
  ]
  
  static values = {
    zoom: { type: Number, default: 1 },
    notification: { type: Boolean, default: false }
  }

  connect() {
    this.loadPDF()
    this.currentMode = null
    
    // Initialize notification functionality if enabled
    if (this.notificationValue) {
      this.setupNotifications()
    }
  }
  
  // Setup global notification function
  setupNotifications() {
    // Make the showNotification function available globally
    window.showNotification = this.showNotification.bind(this)
  }
  
  /**
   * Create and display a notification
   * @param {string} message - Message to display
   * @param {string} type - Type of notification (success, error, warning, info)
   */
  showNotification(message, type = "info") {
    // Find container
    const container = document.getElementById("notification-container")
    if (!container) {
      console.warn("Notification container not found")
      return
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

  // Zoom functionality
  zoomIn() {
    this.zoomValue = Math.min(this.zoomValue * 1.2, 3)
    this.updateZoom()
  }

  zoomOut() {
    this.zoomValue = Math.max(this.zoomValue / 1.2, 0.5)
    this.updateZoom()
  }

  zoomFit() {
    this.zoomValue = 1
    this.updateZoom()
  }

  zoomActual() {
    this.zoomValue = 1
    this.updateZoom()
  }

  updateZoom() {
    this.zoomLevelTarget.textContent = Math.round(this.zoomValue * 100) + '%'
    
    if (this.hasCanvasTarget) {
      this.canvasTarget.style.transform = `scale(${this.zoomValue})`
    }
  }

  // Click handling for positioning
  handleClick(event) {
    const rect = event.currentTarget.getBoundingClientRect()
    const x = ((event.clientX - rect.left) / rect.width) * 100
    const y = ((event.clientY - rect.top) / rect.height) * 100
    
    // Update hidden fields with coordinates
    if (this.hasTextXTarget) this.textXTarget.value = x.toFixed(2)
    if (this.hasTextYTarget) this.textYTarget.value = y.toFixed(2)
    if (this.hasSignatureXTarget) this.signatureXTarget.value = x.toFixed(2)
    if (this.hasSignatureYTarget) this.signatureYTarget.value = y.toFixed(2)
    
    // If we're in a mode where we expect a click, submit the appropriate form
    if (this.currentMode === 'text' && this.hasTextFormTarget) {
      this.submitTextForm(event)
    } else if (this.currentMode === 'type-signature' && this.hasSignatureFormTarget) {
      this.submitSignatureForm(event)
    }
  }

  // Set text mode
  textMode() {
    if (!this.textInputTarget.value.trim()) {
      alert('Enter text first')
      return
    }
    this.currentMode = 'text'
    this.clickOverlayTarget.classList.remove('hidden')
    this.showStatus('Click on PDF to place text', 'blue')
  }
  
  // Handle text form submission
  submitTextForm(event) {
    event.preventDefault()
    if (this.hasTextFormTarget) {
      // Use Turbo to submit the form
      this.textFormTarget.requestSubmit()
      this.resetMode()
    }
  }

  // Set typed signature mode
  typeMode() {
    if (!this.typedSigTarget.value.trim()) {
      alert('Enter name first')
      return
    }
    this.currentMode = 'type-signature'
    this.clickOverlayTarget.classList.remove('hidden')
    this.showStatus('Click on PDF to place typed signature', 'purple')
    
    // Update preview if available
    if (this.hasPreviewTarget) {
      const font = this.signatureFormTarget.querySelector('select[name="font"]').value
      this.previewTarget.style.fontFamily = font
      this.previewTarget.textContent = this.typedSigTarget.value
    }
  }
  
  // Handle signature form submission
  submitSignatureForm(event) {
    event.preventDefault()
    if (this.hasSignatureFormTarget) {
      // Use Turbo to submit the form
      this.signatureFormTarget.requestSubmit()
      this.resetMode()
    }
  }
  
  // Update signature preview when typing or changing font
  updatePreview() {
    if (this.hasPreviewTarget && this.hasTypedSigTarget && this.hasSignatureFormTarget) {
      const font = this.signatureFormTarget.querySelector('select[name="font"]').value
      this.previewTarget.style.fontFamily = font
      this.previewTarget.textContent = this.typedSigTarget.value || 'Preview'
    }
  }

  // Reset mode
  resetMode() {
    this.currentMode = null
    this.clickOverlayTarget.classList.add('hidden')
  }

  // Show status message
  showStatus(message, color) {
    if (this.hasStatusTarget) {
      this.statusTarget.textContent = message
      this.statusTarget.className = `mt-4 p-2 rounded text-white bg-${color}-500`
      this.statusTarget.classList.remove('hidden')
      
      setTimeout(() => this.statusTarget.classList.add('hidden'), 3000)
    }
  }

  // Load PDF (simplified version)
  loadPDF() {
    if (this.hasCanvasTarget) {
      const ctx = this.canvasTarget.getContext('2d')
      
      // Set canvas dimensions
      this.canvasTarget.width = 800
      this.canvasTarget.height = 1000
      
      // Draw placeholder (this would be replaced with actual PDF rendering)
      ctx.fillStyle = '#f0f0f0'
      ctx.fillRect(0, 0, this.canvasTarget.width, this.canvasTarget.height)
      ctx.fillStyle = '#333'
      ctx.font = '24px Arial'
      ctx.textAlign = 'center'
      ctx.fillText('PDF Document', this.canvasTarget.width / 2, this.canvasTarget.height / 2)
      ctx.fillText('Click anywhere to add text or signatures', 
        this.canvasTarget.width / 2, this.canvasTarget.height / 2 + 40)
    }
  }
}
