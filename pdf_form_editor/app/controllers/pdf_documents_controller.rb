class PdfDocumentsController < ApplicationController
  before_action :set_pdf_document, only: [ :show, :edit, :overlay_edit, :simple_edit, :basic_view, :embed_view, :update, :destroy, :add_text, :add_signature, :add_multiple_elements, :remove_element, :download, :stream, :apply_changes, :update_element_position, :save_elements ]
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

    # Reset error status when opening for editing
    if @pdf_document.status == "error"
      @pdf_document.update(status: :uploaded)
    end

    # Clear flash messages that shouldn't persist on page load
    flash.now[:notice] = nil

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

    respond_to do |format|
      format.html { redirect_to pdf_documents_path, notice: "PDF deleted successfully!" }
      format.turbo_stream do
        flash.now[:notice] = "PDF deleted successfully!"
        render turbo_stream: [
          turbo_stream.remove(@pdf_document),
          turbo_stream.replace("flash_messages", partial: "shared/flash_messages")
        ]
      end
    end
  end

  def add_text
    authorize @pdf_document
    x = params[:x].to_f
    y = params[:y].to_f
    content = params[:content] || params[:text] # Support both parameter names for backward compatibility
    page_number = params[:page]&.to_i || 0
    font_name = params[:font] || "Helvetica"
    font_size_pt = params[:font_size]&.to_i || 12

    # Log incoming parameters for debugging
    Rails.logger.info "ADD TEXT: Received params - x: #{x}, y: #{y}, content: #{content}, page: #{page_number}, font: #{font_name}, size: #{font_size_pt}"

    # Validate input
    if content.blank?
      respond_to do |format|
        format.turbo_stream do
          flash.now[:alert] = "Text cannot be blank"
          render turbo_stream: turbo_stream.replace("status_messages",
            partial: "shared/flash_messages")
        end
        format.html { redirect_to overlay_edit_pdf_document_path(@pdf_document), alert: "Text cannot be blank" }
        format.json { render json: { status: "error", message: "Text cannot be blank" }, status: :unprocessable_entity }
      end
      return
    end

    # Validate position - ensure we have coordinates
    if x <= 0 || y <= 0
      Rails.logger.warn "Invalid coordinates for text: x=#{x}, y=#{y}. Using defaults."
      # Use default position in the middle of the page if none provided
      x = 50.0
      y = 50.0
    end

    Rails.logger.info "Adding text to PDF ID: #{@pdf_document.id}, title: #{@pdf_document.title}, content: '#{content}'"

    # Ensure we're working with the correct PDF
    @pdf_document.reload

    # Add the text element directly
    @pdf_document.add_text_element(x, y, content)
    success = true

    respond_to do |format|
      if success
        format.turbo_stream do
          flash.now[:notice] = "Text added successfully"
          @pdf_document.reload # Ensure we have latest elements
          render turbo_stream: [
            turbo_stream.replace("status_messages", partial: "shared/flash_messages"),
            turbo_stream.replace("overlay_elements", partial: "pdf_documents/overlay_elements",
                                locals: { pdf_document: @pdf_document })
          ]
        end
        format.html { redirect_to overlay_edit_pdf_document_path(@pdf_document), notice: "Text added successfully" }
        format.json do
          render json: {
            status: "success",
            message: "Text added successfully to #{@pdf_document.title}",
            pdf_id: @pdf_document.id,
            pdf_title: @pdf_document.title,
            pdf_status: @pdf_document.status
          }
        end
      else
        format.turbo_stream do
          flash.now[:alert] = "Failed to add text to PDF"
          render turbo_stream: turbo_stream.replace("status_messages",
            partial: "shared/flash_messages")
        end
        format.html { redirect_to overlay_edit_pdf_document_path(@pdf_document), alert: "Failed to add text to PDF" }
        format.json { render json: { status: "error", message: "Failed to add text to PDF" }, status: :unprocessable_entity }
      end
    end
  rescue => e
    Rails.logger.error "Error adding text to PDF ID #{@pdf_document.id}: #{e.message}"
    respond_to do |format|
      format.turbo_stream do
        flash.now[:alert] = "Error adding text: #{e.message}"
        render turbo_stream: turbo_stream.replace("status_messages",
          partial: "shared/flash_messages")
      end
      format.html { redirect_to overlay_edit_pdf_document_path(@pdf_document), alert: "Error adding text: #{e.message}" }
      format.json { render json: { status: "error", message: e.message }, status: :unprocessable_entity }
    end
  end

  def add_signature
    authorize @pdf_document
    x = params[:x].to_f
    y = params[:y].to_f
    content = (params[:content] || params[:signature_data]).to_s.strip
    font = params[:font] || "Dancing Script"

    # Log request parameters for debugging
    Rails.logger.info "Adding signature with params: x=#{x}, y=#{y}, content=#{content}, font=#{font}"

    # Validate input
    if content.blank?
      respond_to do |format|
        format.turbo_stream do
          flash.now[:alert] = "Signature content cannot be blank"
          render turbo_stream: turbo_stream.replace("status_messages",
            partial: "shared/flash_messages")
        end
        format.html { redirect_to overlay_edit_pdf_document_path(@pdf_document), alert: "Signature content cannot be blank" }
        format.json { render json: { status: "error", message: "Signature content cannot be blank" }, status: :unprocessable_entity }
      end
      return
    end

    # Validate position - ensure we have coordinates
    if x <= 0 || y <= 0
      Rails.logger.warn "Invalid coordinates for signature: x=#{x}, y=#{y}. Using defaults."
      # Use default position in the middle of the page if none provided
      x = 50.0
      y = 50.0
    end

    Rails.logger.info "Adding signature to PDF ID: #{@pdf_document.id}, title: #{@pdf_document.title}"

    # Add signature as an overlay element
    @pdf_document.add_signature_element(x, y, content, font)

    # Refresh from database to ensure we have the latest data
    @pdf_document.reload

    respond_to do |format|
      format.turbo_stream do
        flash.now[:notice] = "Signature added successfully"
        @pdf_document.reload # Ensure we have latest elements
        render turbo_stream: [
          turbo_stream.replace("status_messages", partial: "shared/flash_messages"),
          turbo_stream.replace("overlay_elements", partial: "pdf_documents/overlay_elements",
                              locals: { pdf_document: @pdf_document })
        ]
      end
      format.html { redirect_to overlay_edit_pdf_document_path(@pdf_document), notice: "Signature added successfully" }
      format.json {
        render json: {
          status: "success",
          message: "Signature added successfully to #{@pdf_document.title}",
          pdf_id: @pdf_document.id
        }
      }
    end
  rescue => e
    Rails.logger.error "Error adding signature: #{e.message}"
    respond_to do |format|
      format.turbo_stream do
        flash.now[:alert] = "Failed to add signature to PDF: #{e.message}"
        render turbo_stream: turbo_stream.replace("status_messages",
          partial: "shared/flash_messages")
      end
      format.html { redirect_to overlay_edit_pdf_document_path(@pdf_document), alert: "Failed to add signature to PDF" }
      format.json { render json: { status: "error", message: "Failed to add signature to PDF" }, status: :unprocessable_entity }
    end
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
    }
  end

  def download
    authorize @pdf_document

    if @pdf_document.pdf_file.attached?
      # For now, always download the original PDF to avoid processing issues
      # TODO: Re-enable processed PDF once saving is fixed
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

  # Remove an element from the PDF by index
  def remove_element
    authorize @pdf_document
    index = params[:index].to_i
    @pdf_document.remove_element(index)

    respond_to do |format|
      format.turbo_stream do
        flash.now[:notice] = "Element removed successfully"
        render turbo_stream: [
          turbo_stream.replace("status_messages", partial: "shared/flash_messages"),
          turbo_stream.replace("overlay_elements", partial: "pdf_documents/overlay_elements",
                              locals: { pdf_document: @pdf_document })
        ]
      end
      format.html { redirect_to overlay_edit_pdf_document_path(@pdf_document), notice: "Element removed successfully!" }
      format.json { render json: { status: "success", message: "Element removed successfully" } }
    end
  rescue => e
    Rails.logger.error "Error removing element: #{e.message}"
    respond_to do |format|
      format.turbo_stream do
        flash.now[:alert] = "Error removing element: #{e.message}"
        render turbo_stream: turbo_stream.replace("status_messages",
          partial: "shared/flash_messages")
      end
      format.html { redirect_to overlay_edit_pdf_document_path(@pdf_document), alert: "Error removing element: #{e.message}" }
      format.json { render json: { status: "error", message: e.message }, status: :unprocessable_entity }
    end
  end

  # Apply all changes and generate the final PDF
  def apply_changes
    authorize @pdf_document
    Rails.logger.info "Starting apply_changes for PDF #{@pdf_document.id}"
    Rails.logger.info "Request format: #{request.format}, XHR: #{request.xhr?}, Accept: #{request.headers['Accept']}"

    # Force JSON response for fetch requests from our JavaScript
    if request.xhr? || request.headers["Accept"].to_s.include?("application/json")
      request.format = :json
      Rails.logger.info "Forcing JSON response format"
    end

    # First verify if PDF file is attached and elements exist
    if !@pdf_document.pdf_file.attached?
      Rails.logger.error "No PDF file attached to document #{@pdf_document.id}"
      if request.xhr? || request.format.json?
        return render json: { status: "error", message: "No PDF file attached" }, status: :unprocessable_entity
      else
        return redirect_to overlay_edit_pdf_document_path(@pdf_document), alert: "No PDF file attached"
      end
    end

    if @pdf_document.overlay_elements.blank?
      Rails.logger.warn "No overlay elements for PDF #{@pdf_document.id}"
    end

    # Try to apply the elements
    begin
      Rails.logger.info "Calling apply_all_elements for PDF #{@pdf_document.id}"

      result = @pdf_document.apply_all_elements
      Rails.logger.info "Result of apply_all_elements: #{result}"

      if result
        Rails.logger.info "Successfully applied changes to PDF #{@pdf_document.id}"
        if request.xhr? || request.format.json?
          render json: { status: "success", message: "All changes saved successfully" }
        else
          redirect_to overlay_edit_pdf_document_path(@pdf_document), notice: "All changes saved successfully!"
        end
      else
        Rails.logger.error "Failed to apply changes to PDF #{@pdf_document.id}"
        if request.xhr? || request.format.json?
          render json: { status: "error", message: "Failed to apply changes" }, status: :unprocessable_entity
        else
          redirect_to overlay_edit_pdf_document_path(@pdf_document), alert: "Failed to apply changes"
        end
      end
    rescue => e
      Rails.logger.error "Error applying changes to PDF #{@pdf_document.id}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      if request.xhr? || request.format.json?
        render json: { status: "error", message: e.message }, status: :unprocessable_entity
      else
        redirect_to overlay_edit_pdf_document_path(@pdf_document), alert: "Error applying changes: #{e.message}"
      end
    end
  end

  # Update position of an overlay element
  def update_element_position
    authorize @pdf_document
    index = params[:index].to_i
    x = params[:x].to_f
    y = params[:y].to_f

    begin
      if @pdf_document.update_element_position(index, x, y)
        render json: { status: "success", message: "Element position updated" }
      else
        render json: { status: "error", message: "Failed to update element position" }, status: :unprocessable_entity
      end
    rescue => e
      Rails.logger.error "Error updating element position: #{e.message}"
      render json: { status: "error", message: e.message }, status: :unprocessable_entity
    end
  end

  # Save all overlay elements at once
  def save_elements
    authorize @pdf_document

    # Log everything we receive for debugging
    Rails.logger.info "=== SAVE ELEMENTS DEBUG ==="
    Rails.logger.info "PDF ID: #{@pdf_document.id}"
    Rails.logger.info "Content Type: #{request.content_type}"
    Rails.logger.info "Format: #{request.format}"
    Rails.logger.info "Params: #{params.inspect}"
    Rails.logger.info "Raw post: #{request.raw_post[0..200]}" if request.raw_post.present?

    # Very simple implementation for now
    begin
      # Get the elements
      elements_param = params[:elements]

      # Simple validation
      if elements_param.blank?
        Rails.logger.warn "Elements parameter is blank"
        render json: { status: "error", message: "Elements parameter is blank" }, status: :unprocessable_entity
        return
      end

      # Try to handle both string JSON and structured data
      elements = nil

      if elements_param.is_a?(String)
        Rails.logger.info "Elements received as string, parsing JSON"
        elements = JSON.parse(elements_param)
      elsif elements_param.is_a?(Array)
        Rails.logger.info "Elements received as array"
        elements = elements_param
      elsif elements_param.is_a?(Hash)
        Rails.logger.info "Elements received as hash"
        elements = [ elements_param ]
      else
        Rails.logger.info "Elements are of unknown type: #{elements_param.class}"
        elements = [ elements_param ]
      end

      Rails.logger.info "Final elements to save: #{elements.inspect[0..100]}..."

      # Update the document
      @pdf_document.update!(overlay_elements: elements)
      Rails.logger.info "Successfully updated PDF #{@pdf_document.id}"

      # Send response based on format
      respond_to do |format|
        format.json { render json: { status: "success", message: "Elements saved successfully" } }
        format.html { redirect_to overlay_edit_pdf_document_path(@pdf_document), notice: "Elements saved successfully" }
      end
    rescue => e
      Rails.logger.error "Error saving elements: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      render json: { status: "error", message: "Error saving: #{e.message}" }, status: :unprocessable_entity
    end
  end

  private

  def add_text_element
    authorize @pdf_document
    x = params[:x].to_f
    y = params[:y].to_f
    content = params[:content]

    if content.present?
      @pdf_document.add_text_element(x, y, content)
      redirect_to overlay_edit_pdf_document_path(@pdf_document), notice: "Text added successfully!"
    else
      redirect_to overlay_edit_pdf_document_path(@pdf_document), alert: "Please enter text content."
    end
  end

  def add_signature_element
    authorize @pdf_document
    x = params[:x].to_f
    y = params[:y].to_f
    content = params[:content]
    font = params[:font] || "Dancing Script"

    if content.present?
      @pdf_document.add_signature_element(x, y, content, font)
      redirect_to overlay_edit_pdf_document_path(@pdf_document), notice: "Signature added successfully!"
    else
      redirect_to overlay_edit_pdf_document_path(@pdf_document), alert: "Please enter signature content."
    end
  end

  def set_pdf_document
    @pdf_document = current_user.pdf_documents.find(params[:id])
  end

  def pdf_document_params
    params.require(:pdf_document).permit(:title, :pdf_file)
  end
end
