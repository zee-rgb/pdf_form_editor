// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
import "alpinejs"

// Initialize Alpine.js
window.Alpine = Alpine
Alpine.start()
