# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"

pin_all_from "app/javascript/controllers", under: "controllers"

# PDF.js - using version 3.4.120 to avoid private member errors
pin "pdfjs-dist", to: "https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.4.120/pdf.min.js"
pin "pdfjs-worker", to: "https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.4.120/pdf.worker.min.js"

# Alpine.js
pin "alpinejs", to: "https://unpkg.com/alpinejs@3.x.x/dist/cdn.min.js"

# Internal scripts
pin "share-modal", to: "share-modal.js"
