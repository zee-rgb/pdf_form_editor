import { Controller } from "@hotwired/stimulus"

// Signature preview controller
export default class extends Controller {
  static targets = ["input", "font", "preview"]
  
  connect() {
    // Setup event listeners
    if (this.hasInputTarget && this.hasFontTarget) {
      this.inputTarget.addEventListener('input', this.updatePreview.bind(this));
      this.fontTarget.addEventListener('change', this.updatePreview.bind(this));
      
      // Initial update if there's already content
      if (this.inputTarget.value.trim()) {
        this.updatePreview();
      }
    }
  }
  
  disconnect() {
    if (this.hasInputTarget && this.hasFontTarget) {
      this.inputTarget.removeEventListener('input', this.updatePreview.bind(this));
      this.fontTarget.removeEventListener('change', this.updatePreview.bind(this));
    }
  }
  
  updatePreview() {
    const content = this.inputTarget.value;
    const font = this.fontTarget.value;
    const previewElement = this.previewTarget;
    
    if (!content.trim()) {
      previewElement.innerHTML = '<div class="signature-placeholder text-gray-400 italic text-sm">Type your name above to see preview</div>';
      return;
    }
    
    previewElement.innerHTML = '<div class="animate-pulse">Generating preview...</div>';
    
    // Create SVG preview directly without server call
    const fontFamily = this.getFontFamily(font);
    const svg = `
      <svg xmlns="http://www.w3.org/2000/svg" width="100%" height="100%">
        <style>
          @import url('https://fonts.googleapis.com/css2?family=Dancing+Script&family=Great+Vibes&family=Allura&display=swap');
          .signature-text {
            font-family: ${fontFamily};
            font-size: 24px;
            fill: #000000;
          }
        </style>
        <text x="50%" y="50%" text-anchor="middle" dominant-baseline="middle" class="signature-text">${content}</text>
      </svg>
    `;
    
    previewElement.innerHTML = svg;
  }
  
  getFontFamily(font) {
    switch (font) {
      case "Dancing Script":
        return "'Dancing Script', cursive";
      case "Great Vibes":
        return "'Great Vibes', cursive";
      case "Allura":
        return "'Allura', cursive";
      default:
        return "Arial, sans-serif";
    }
  }
}
