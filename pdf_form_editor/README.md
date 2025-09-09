# PDF Form Editor

A modern web application for editing and filling non-fillable PDF forms with text and signatures.

## ✨ Features

- **📄 PDF Upload & Management** - Upload and organize your PDF documents
- **✏️ Click-to-Add Text** - Click anywhere on a PDF to add text fields
- **✍️ Multiple Signature Options**:
  - Draw signatures with your mouse or finger
  - Upload signature images (PNG, JPG, etc.)
  - Type signatures with cursive fonts
- **📱 Mobile Responsive** - Works seamlessly on desktop and mobile devices
- **🔒 User Authentication** - Secure user accounts and document privacy
- **⬇️ Download Completed PDFs** - Export your filled forms as new PDF files
- **🎨 Modern UI** - Clean, intuitive interface built with Tailwind CSS

## 🛠️ Tech Stack

- **Backend**: Ruby on Rails 8 with Hotwire/Turbo
- **Frontend**: Alpine.js, Tailwind CSS
- **PDF Processing**: 
  - PDF.js for browser rendering
  - HexaPDF for server-side manipulation
- **Authentication**: Devise
- **Authorization**: Pundit
- **Database**: PostgreSQL (development: SQLite)
- **File Storage**: Active Storage

## 🚀 Quick Start

### Prerequisites

- Ruby 3.4+ 
- Rails 8+
- Node.js (for esbuild)
- PostgreSQL (for production)

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd pdf_form_editor
   ```

2. **Install dependencies**
   ```bash
   bundle install
   ```

3. **Setup database**
   ```bash
   rails db:create
   rails db:migrate
   ```

4. **Generate sample PDF (optional)**
   ```bash
   rails sample:pdf
   ```

5. **Start the server**
   ```bash
   rails server
   ```

6. **Visit the application**
   Open http://localhost:3000 in your browser

## 📖 Usage Guide

### Getting Started

1. **Sign Up** - Create a new account or log in
2. **Upload a PDF** - Use the drag-and-drop interface or browse for files
3. **Edit Your PDF** - Click on any area to add text or signatures
4. **Download** - Save your completed PDF

### Adding Text

1. Type your text in the sidebar input field
2. Click anywhere on the PDF where you want to place the text
3. The text will be overlaid on the PDF at that position

### Adding Signatures

**Draw Signature:**
1. Select "Draw" tab in the signature section
2. Draw your signature on the canvas using mouse/finger
3. Click "Use Signature" when satisfied
4. Click on the PDF where you want to place it

**Upload Signature:**
1. Select "Upload" tab
2. Choose an image file with your signature
3. Click "Use Signature" 
4. Click on the PDF to place it

**Type Signature:**
1. Select "Type" tab
2. Type your name in the input field
3. Select a font style (cursive fonts available)
4. Click "Use Signature"
5. Click on the PDF to place it

## 🔧 Configuration

### Environment Variables

For production deployment, configure:

- `DATABASE_URL` - PostgreSQL connection string
- `SECRET_KEY_BASE` - Rails secret key
- `RAILS_ENV=production`

### File Storage

The application uses Active Storage with local disk storage by default. For production, configure cloud storage (AWS S3, etc.) in `config/storage.yml`.

## 🧪 Testing

Generate a sample PDF for testing:

```bash
rails sample:pdf
```

This creates a sample form at `public/sample_form.pdf` that you can upload and test with.

## 📁 Project Structure

```
app/
├── controllers/
│   ├── application_controller.rb    # Base controller with Pundit
│   └── pdf_documents_controller.rb  # PDF CRUD and editing endpoints
├── models/
│   ├── user.rb                     # Devise user model
│   └── pdf_document.rb             # PDF document model with HexaPDF
├── policies/
│   ├── application_policy.rb       # Base Pundit policy
│   └── pdf_document_policy.rb      # PDF authorization rules
└── views/
    ├── layouts/application.html.erb # Main layout with navigation
    └── pdf_documents/
        ├── index.html.erb          # PDF list page
        ├── new.html.erb            # PDF upload form
        └── edit.html.erb           # PDF editor with Alpine.js
```

## 🔒 Security Features

- **User Authentication** - Devise handles secure user registration/login
- **Authorization** - Pundit ensures users can only access their own PDFs
- **CSRF Protection** - Rails built-in CSRF tokens
- **Server-side Processing** - PDF modifications happen on the server for security

## 🚢 Deployment

### Render (Recommended)

1. Connect your GitHub repository to Render
2. Set up a PostgreSQL database
3. Configure environment variables
4. Deploy the web service

### Manual Deployment

1. Set up production environment
2. Configure database and environment variables
3. Precompile assets: `rails assets:precompile`
4. Run migrations: `rails db:migrate RAILS_ENV=production`
5. Start server: `rails server -e production`

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 🐛 Troubleshooting

### Common Issues

**PDF not loading:**
- Ensure PDF.js assets are properly loaded
- Check browser console for JavaScript errors
- Verify PDF file is not corrupted

**Signature drawing not working:**
- Clear browser cache
- Ensure JavaScript is enabled
- Try a different browser

**Upload fails:**
- Check file size limits in Rails configuration
- Ensure proper file permissions
- Verify Active Storage configuration

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [PDF.js](https://mozilla.github.io/pdf.js/) - PDF rendering in the browser
- [HexaPDF](https://hexapdf.gettalong.org/) - Ruby PDF processing library
- [Alpine.js](https://alpinejs.dev/) - Lightweight JavaScript framework
- [Tailwind CSS](https://tailwindcss.com/) - Utility-first CSS framework
