import { Controller } from "@hotwired/stimulus"

// Resize controller for resizing text and signature elements
export default class extends Controller {
  connect() {
    this.resizeHandle = this.element.querySelector('.resize-handle');
    if (this.resizeHandle) {
      this.resizeHandle.addEventListener('mousedown', this.startResize.bind(this));
    }
  }

  disconnect() {
    if (this.resizeHandle) {
      this.resizeHandle.removeEventListener('mousedown', this.startResize.bind(this));
    }
  }

  startResize(event) {
    event.preventDefault();
    event.stopPropagation(); // Prevent drag event from triggering
    
    // Store initial mouse position and element size
    this.resizing = true;
    this.initialX = event.clientX;
    this.initialY = event.clientY;
    this.initialWidth = this.element.offsetWidth;
    this.initialHeight = this.element.offsetHeight;
    
    // Add event listeners for resize and end
    document.addEventListener('mousemove', this.resize.bind(this));
    document.addEventListener('mouseup', this.endResize.bind(this));
    
    // Add resizing class for visual feedback
    this.element.classList.add('resizing');
  }

  resize(event) {
    if (!this.resizing) return;
    
    event.preventDefault();
    
    // Calculate new dimensions
    const deltaX = event.clientX - this.initialX;
    const deltaY = event.clientY - this.initialY;
    const parentRect = this.element.parentElement.getBoundingClientRect();
    
    // Ensure minimum size
    const minWidth = 60; // minimum width in pixels
    const minHeight = 20; // minimum height in pixels
    
    // Calculate new width and height
    const newWidth = Math.max(minWidth, this.initialWidth + deltaX);
    const newHeight = Math.max(minHeight, this.initialHeight + deltaY);
    
    // Convert to percentages of parent
    const widthPercent = (newWidth / parentRect.width) * 100;
    const heightPercent = (newHeight / parentRect.height) * 100;
    
    // Update element size
    this.element.style.width = `${widthPercent}%`;
    this.element.style.height = `${heightPercent}%`;
    
    // Dispatch a custom event to notify about size change
    const resizeEvent = new CustomEvent('size-changed', {
      detail: {
        elementId: this.element.dataset.elementId,
        width: widthPercent,
        height: heightPercent
      },
      bubbles: true
    });
    this.element.dispatchEvent(resizeEvent);
  }

  endResize() {
    if (!this.resizing) return;
    
    this.resizing = false;
    this.element.classList.remove('resizing');
    
    // Remove event listeners
    document.removeEventListener('mousemove', this.resize);
    document.removeEventListener('mouseup', this.endResize);
    
    // Save the final size to the server
    this.saveSize();
  }
  
  saveSize() {
    // Get the current size
    const width = parseFloat(this.element.style.width);
    const height = parseFloat(this.element.style.height);
    const elementId = this.element.dataset.elementId;
    
    // TODO: Implement server-side update for element size
    console.log(`Element ${elementId} size updated to: width=${width}%, height=${height}%`);
  }
}
