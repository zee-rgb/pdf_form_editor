import { Controller } from "@hotwired/stimulus"

// Drag controller for moving text and signature elements
export default class extends Controller {
  connect() {
    this.element.style.cursor = "move";
    this.element.addEventListener('mousedown', this.startDrag.bind(this));
  }

  disconnect() {
    this.element.removeEventListener('mousedown', this.startDrag.bind(this));
  }

  startDrag(event) {
    // Don't start drag if clicking on remove button or resize handle
    if (event.target.closest('.remove-btn') || event.target.closest('.resize-handle')) {
      return;
    }
    
    event.preventDefault();

    // Store initial mouse position and element position
    this.dragging = true;
    this.initialX = event.clientX;
    this.initialY = event.clientY;
    this.initialLeft = parseFloat(this.element.style.left) || 0;
    this.initialTop = parseFloat(this.element.style.top) || 0;
    
    // Add event listeners for drag and end
    document.addEventListener('mousemove', this.drag.bind(this));
    document.addEventListener('mouseup', this.endDrag.bind(this));
    
    // Add dragging class for visual feedback
    this.element.classList.add('dragging');
  }

  drag(event) {
    if (!this.dragging) return;
    
    event.preventDefault();
    
    // Calculate new position as percentage of parent container
    const parentRect = this.element.parentElement.getBoundingClientRect();
    const deltaX = event.clientX - this.initialX;
    const deltaY = event.clientY - this.initialY;
    
    // Convert pixel changes to percentage of container
    const percentX = (deltaX / parentRect.width) * 100;
    const percentY = (deltaY / parentRect.height) * 100;
    
    // Update element position
    const newLeft = this.initialLeft + percentX;
    const newTop = this.initialTop + percentY;
    
    this.element.style.left = `${newLeft}%`;
    this.element.style.top = `${newTop}%`;
    
    // Dispatch a custom event to notify about position change
    const positionEvent = new CustomEvent('position-changed', {
      detail: {
        elementId: this.element.dataset.elementId,
        x: newLeft,
        y: newTop
      },
      bubbles: true
    });
    this.element.dispatchEvent(positionEvent);
  }

  endDrag() {
    if (!this.dragging) return;
    
    this.dragging = false;
    this.element.classList.remove('dragging');
    
    // Remove event listeners
    document.removeEventListener('mousemove', this.drag);
    document.removeEventListener('mouseup', this.endDrag);
    
    // Save the final position to the server
    this.savePosition();
  }
  
  savePosition() {
    // Get the current position
    const x = parseFloat(this.element.style.left);
    const y = parseFloat(this.element.style.top);
    const elementId = this.element.dataset.elementId;
    
    // Get the PDF document ID from the URL
    const pathParts = window.location.pathname.split('/');
    const pdfDocumentId = pathParts[pathParts.indexOf('pdf_documents') + 1];
    
    // Send AJAX request to update element position
    fetch(`/pdf_documents/${pdfDocumentId}/update_element_position`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
      },
      body: JSON.stringify({
        index: elementId,
        x: x,
        y: y
      })
    })
    .then(response => response.json())
    .then(data => {
      if (data.status === 'success') {
        console.log(`Element ${elementId} position updated to: x=${x}%, y=${y}%`);
      } else {
        console.error('Failed to update element position:', data.message);
      }
    })
    .catch(error => {
      console.error('Error saving position:', error);
    });
  }
}
