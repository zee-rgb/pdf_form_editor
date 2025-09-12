# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"

# Explicitly pin all controllers
pin "controllers/application", to: "controllers/application.js"
pin "controllers/hello_controller", to: "controllers/hello_controller.js"
pin "controllers/drag_controller", to: "controllers/drag_controller.js"
pin "controllers/notification_controller", to: "controllers/notification_controller.js"
pin "controllers/pdf_editor_controller", to: "controllers/pdf_editor_controller.js"
pin "controllers/resize_controller", to: "controllers/resize_controller.js"
pin "controllers/signature_preview_controller", to: "controllers/signature_preview_controller.js"
pin "controllers/index", to: "controllers/index.js"
pin "controllers/stimulus-register", to: "controllers/stimulus-register.js"

# PDF.js - using version 3.4.120 to avoid private member errors
pin "pdfjs-dist", to: "https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.4.120/pdf.min.js"
pin "pdfjs-worker", to: "https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.4.120/pdf.worker.min.js"

# Custom scripts removed to avoid 'skipped missing path' warnings

# Alpine.js
pin "alpinejs", to: "https://unpkg.com/alpinejs@3.x.x/dist/cdn.min.js"

# Internal scripts
pin "share-modal", to: "share-modal.js"
