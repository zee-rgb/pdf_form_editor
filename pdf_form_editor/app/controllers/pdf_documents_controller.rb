class PdfDocumentsController < ApplicationController
  before_action :set_pdf_document, only: [ :show, :edit, :overlay_edit, :simple_edit, :basic_view, :embed_view, :update, :destroy, :add_text, :add_signature, :add_multiple_elements, :download, :stream ]
  skip_before_action :verify_authenticity_token, only: [ :stream ]

  def index
    @pdf_documents = policy_scope(PdfDocument).order(created_at: :desc)
  end

  def show
    authorize @pdf_document
    # PDF viewer page
  end

  def new
    @pdf_document = current_user.pdf_documents.build
    authorize @pdf_document
  end

  def create
    @pdf_document = current_user.pdf_documents.build(pdf_document_params)
    authorize @pdf_document
    @pdf_document.status = :uploaded

    if @pdf_document.save
      redirect_to overlay_edit_pdf_document_path(@pdf_document, format: :html), notice: "PDF uploaded successfully!"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @pdf_document
    # Redirect the legacy edit route to the overlay editor for a simpler UX
    redirect_to overlay_edit_pdf_document_path(@pdf_document)
  end

  def simple_edit
    authorize @pdf_document
    # Simplified PDF viewing/editing page that uses basic PDF.js
    render "simple_view"
  end

  def basic_view
    authorize @pdf_document
    # Extremely simplified PDF viewer with minimal JS
  end

  def embed_view
    authorize @pdf_document
    # HTML-only PDF viewer with embed tag - no JavaScript needed
  end

  def overlay_edit
    authorize @pdf_document
    # Force HTML template when navigated from a turbo_stream redirect
    respond_to do |format|
      format.html { render "edit_overlay" }
      format.turbo_stream { redirect_to overlay_edit_pdf_document_path(@pdf_document, format: :html) }
    end
  end

  def update
    authorize @pdf_document
    if @pdf_document.update(pdf_document_params)
      redirect_to @pdf_document, notice: "PDF updated successfully!"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @pdf_document
    @pdf_document.destroy
    redirect_to pdf_documents_path, notice: "PDF deleted successfully!"
  end

  def add_text
    authorize @pdf_document
    x = params[:x].to_f
    y = params[:y].to_f
    text = params[:text]
    page = params[:page]&.to_i || 0

    # Validate input
    if text.blank?
      render json: {
        status: "error",
        message: "Text cannot be blank"
      }, status: :unprocessable_entity
      return
    end

    Rails.logger.info "Adding text to PDF ID: #{@pdf_document.id}, title: #{@pdf_document.title}, text: '#{text}'"

    # Ensure we're working with the correct PDF
    @pdf_document.reload

    @pdf_document.add_text_overlay(x, y, text, page)

    render json: {
      status: "success",
      message: "Text added successfully to #{@pdf_document.title}",
      pdf_id: @pdf_document.id,
      pdf_title: @pdf_document.title,
      pdf_status: @pdf_document.status
    }
  rescue => e
    Rails.logger.error "Error adding text to PDF ID #{@pdf_document.id}: #{e.message}"
    render json: {
      status: "error",
      message: e.message
    }, status: :unprocessable_entity
  end

  def add_signature
    authorize @pdf_document
    x = params[:x].to_f
    y = params[:y].to_f
    signature_data = params[:signature_data]
    page = params[:page]&.to_i || 0

    Rails.logger.info "Adding signature to PDF ID: #{@pdf_document.id}, title: #{@pdf_document.title}"
    @pdf_document.reload
    @pdf_document.add_signature_overlay(x, y, signature_data, page)

    render json: {
      status: "success",
      message: "Signature added successfully to #{@pdf_document.title}",
      pdf_id: @pdf_document.id
    }
  rescue => e
    Rails.logger.error "Error adding signature to PDF ID #{@pdf_document.id}: #{e.message}"
    render json: {
      status: "error",
      message: e.message
    }, status: :unprocessable_entity
  end

  def add_multiple_elements
    authorize @pdf_document
    elements = params[:elements] || []

    if elements.empty?
      render json: {
        status: "error",
        message: "No elements to add"
      }, status: :unprocessable_entity
      return
    end

    Rails.logger.info "Adding #{elements.length} elements to PDF ID: #{@pdf_document.id}, title: #{@pdf_document.title}"

    # Ensure we're working with the correct PDF
    @pdf_document.reload

    # Process all elements in one go
    @pdf_document.add_multiple_overlays(elements)

    render json: {
      status: "success",
      message: "All #{elements.length} elements added successfully to #{@pdf_document.title}",
      pdf_id: @pdf_document.id,
      pdf_title: @pdf_document.title,
      pdf_status: @pdf_document.status
    }
  rescue => e
    Rails.logger.error "Error adding multiple elements to PDF ID #{@pdf_document&.id}: #{e.message}"
    Rails.logger.error "Backtrace: #{e.backtrace.first(5).join('\n')}"
    render json: {
      status: "error",
      message: e.message,
      details: e.class.name
    }, status: :unprocessable_entity
  end

  def download
    authorize @pdf_document
    if @pdf_document.processed_pdf.attached?
      send_data @pdf_document.processed_pdf.download,
                filename: @pdf_document.processed_pdf.filename.to_s,
                type: "application/pdf",
                disposition: "attachment"
    elsif @pdf_document.pdf_file.attached?
      # Fallback to original PDF to avoid dead ends
      send_data @pdf_document.pdf_file.download,
                filename: @pdf_document.pdf_file.filename.to_s,
                type: "application/pdf",
                disposition: "attachment"
    else
      redirect_back(fallback_location: pdf_documents_path, alert: "No PDF available to download")
    end
  end

  def stream
    authorize @pdf_document
    Rails.logger.info "Streaming PDF ID: #{@pdf_document.id}, Title: #{@pdf_document.title}"

    # Force reload to get latest processed_pdf
    @pdf_document.reload

    # Set CORS headers for PDF.js
    response.headers["Access-Control-Allow-Origin"] = "*"
    response.headers["Access-Control-Allow-Methods"] = "GET"
    response.headers["Access-Control-Allow-Headers"] = "Range"
    response.headers["Accept-Ranges"] = "bytes"
    response.headers["Cache-Control"] = "no-cache, no-store, must-revalidate"
    response.headers["Pragma"] = "no-cache"
    response.headers["Expires"] = "0"

    pdf_data = nil
    filename = nil

    if @pdf_document.processed_pdf.attached?
      blob_id = @pdf_document.processed_pdf.blob.id
      blob_key = @pdf_document.processed_pdf.blob.key
      Rails.logger.info "Serving processed PDF for ID: #{@pdf_document.id}, blob_id: #{blob_id}, key: #{blob_key}"
      pdf_data = @pdf_document.processed_pdf.download
      filename = @pdf_document.processed_pdf.filename.to_s
      Rails.logger.info "Downloaded #{pdf_data.size} bytes for PDF #{@pdf_document.id}"
    elsif @pdf_document.pdf_file.attached?
      blob_id = @pdf_document.pdf_file.blob.id
      blob_key = @pdf_document.pdf_file.blob.key
      Rails.logger.info "Serving original PDF for ID: #{@pdf_document.id}, blob_id: #{blob_id}, key: #{blob_key}"
      pdf_data = @pdf_document.pdf_file.download
      filename = @pdf_document.pdf_file.filename.to_s
      Rails.logger.info "Downloaded #{pdf_data.size} bytes for PDF #{@pdf_document.id}"
    else
      Rails.logger.warn "No PDF file found for ID: #{@pdf_document.id}"
      head :not_found
      return
    end

    # Handle range requests for better PDF.js compatibility
    if request.headers["Range"]
      Rails.logger.info "Range request for PDF ID: #{@pdf_document.id}"
      send_data pdf_data,
                filename: filename,
                type: "application/pdf",
                disposition: "inline",
                status: :partial_content
    else
      send_data pdf_data,
                filename: filename,
                type: "application/pdf",
                disposition: "inline"
    end
  end

  private

  def set_pdf_document
    @pdf_document = current_user.pdf_documents.find(params[:id])
  end

  def pdf_document_params
    params.require(:pdf_document).permit(:title, :pdf_file)
  end
end
