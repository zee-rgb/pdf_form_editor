# frozen_string_literal: true

require "rails_helper"

RSpec.describe "PdfDocuments", type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }

  before do
    login_as user, scope: :user
  end

  describe "GET /pdf_documents" do
    it "returns http success" do
      get pdf_documents_path
      expect(response).to have_http_status(:success)
    end

    it "displays user's pdf documents" do
      pdf_document = create(:pdf_document, user: user, title: "My Document")
      other_pdf = create(:pdf_document, user: other_user, title: "Other Document")

      get pdf_documents_path

      expect(response.body).to include("My Document")
      expect(response.body).not_to include("Other Document")
    end

    it "shows welcome message when no documents exist" do
      get pdf_documents_path

      expect(response.body).to include("Transform non-fillable PDFs")
    end
  end

  describe "GET /pdf_documents/new" do
    it "returns http success" do
      get new_pdf_document_path
      expect(response).to have_http_status(:success)
    end

    it "displays upload form" do
      get new_pdf_document_path

      expect(response.body).to include("Upload a PDF file")
      expect(response.body).to include("pdf_document[pdf_file]")
    end
  end

  describe "POST /pdf_documents" do
    let(:valid_params) do
      {
        pdf_document: {
          title: "Test Document",
          pdf_file: fixture_file_upload("test.pdf", "application/pdf")
        }
      }
    end

    before do
      # Create a simple test PDF file
      test_pdf_content = "%PDF-1.4\n1 0 obj\n<<\n/Type /Catalog\n/Pages 2 0 R\n>>\nendobj\nxref\n0 2\ntrailer\n<<\n/Size 2\n/Root 1 0 R\n>>\nstartxref\n%%EOF"
      File.write(Rails.root.join("spec/fixtures/test.pdf"), test_pdf_content)
    end

    after do
      File.delete(Rails.root.join("spec/fixtures/test.pdf")) if File.exist?(Rails.root.join("spec/fixtures/test.pdf"))
    end

    it "creates a new pdf document" do
      expect {
        post pdf_documents_path, params: valid_params
      }.to change(PdfDocument, :count).by(1)
    end

    it "redirects to the document after creation" do
      post pdf_documents_path, params: valid_params

      expect(response).to have_http_status(:redirect)
      pdf_document = PdfDocument.last
      expect(response).to redirect_to(pdf_document)
    end

    it "associates document with current user" do
      post pdf_documents_path, params: valid_params

      pdf_document = PdfDocument.last
      expect(pdf_document.user).to eq(user)
    end
  end

  describe "GET /pdf_documents/:id/edit" do
    let(:pdf_document) { create(:pdf_document, user: user) }

    it "returns http success for owner" do
      get edit_pdf_document_path(pdf_document)
      expect(response).to have_http_status(:success)
    end

    it "includes PDF editor interface" do
      get edit_pdf_document_path(pdf_document)

      expect(response.body).to include("pdfEditor()")
      expect(response.body).to include("Add Text")
      expect(response.body).to include("Add Signature")
    end

    it "denies access to other users" do
      other_pdf = create(:pdf_document, user: other_user)

      get edit_pdf_document_path(other_pdf)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /pdf_documents/:id/add_text" do
    let(:pdf_document) { create(:pdf_document, user: user) }
    let(:text_params) do
      {
        x: 100.0,
        y: 200.0,
        text: "Sample Text",
        page: 0
      }
    end

    it "adds text to PDF" do
      post add_text_pdf_document_path(pdf_document),
           params: text_params

      expect(response).to have_http_status(:success)
      json_response = JSON.parse(response.body)
      expect(json_response["status"]).to eq("success")
    end

    it "denies access to other users" do
      other_pdf = create(:pdf_document, user: other_user)

      post add_text_pdf_document_path(other_pdf),
           params: text_params
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /pdf_documents/:id/add_signature" do
    let(:pdf_document) { create(:pdf_document, user: user) }
    let(:signature_params) do
      {
        x: 100.0,
        y: 200.0,
        signature_data: "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI7wAAAABJRU5ErkJggg==",
        page: 0
      }
    end

    it "adds signature to PDF" do
      post add_signature_pdf_document_path(pdf_document),
           params: signature_params

      expect(response).to have_http_status(:success)
      json_response = JSON.parse(response.body)
      expect(json_response["status"]).to eq("success")
    end

    it "denies access to other users" do
      other_pdf = create(:pdf_document, user: other_user)

      post add_signature_pdf_document_path(other_pdf),
           params: signature_params
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /pdf_documents/:id/download" do
    let(:pdf_document) { create(:pdf_document, :with_processed_pdf, user: user) }

    it "downloads processed PDF for owner" do
      get download_pdf_document_path(pdf_document)

      expect(response).to have_http_status(:success)
      expect(response.headers["Content-Type"]).to eq("application/pdf")
      expect(response.headers["Content-Disposition"]).to include("attachment")
    end

    it "denies access to other users" do
      other_pdf = create(:pdf_document, :with_processed_pdf, user: other_user)

      get download_pdf_document_path(other_pdf)
      expect(response).to have_http_status(:not_found)
    end

    it "redirects when no processed PDF exists" do
      pdf_without_processed = create(:pdf_document, user: user)

      get download_pdf_document_path(pdf_without_processed)

      expect(response).to have_http_status(:redirect)
    end
  end

  describe "DELETE /pdf_documents/:id" do
    let(:pdf_document) { create(:pdf_document, user: user) }

    it "deletes the document for owner" do
      pdf_document # Create the document

      expect {
        delete pdf_document_path(pdf_document)
      }.to change(PdfDocument, :count).by(-1)
    end

    it "redirects to index after deletion" do
      delete pdf_document_path(pdf_document)

      expect(response).to redirect_to(pdf_documents_path)
    end

    it "denies access to other users" do
      other_pdf = create(:pdf_document, user: other_user)

      delete pdf_document_path(other_pdf)
      expect(response).to have_http_status(:not_found)
    end
  end

  context "when not authenticated" do
    before { logout }

    it "redirects to login page" do
      get pdf_documents_path
      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
