class PdfDocumentsController < ApplicationController
  before_action :set_pdf_document, only: [ :show, :edit, :update, :destroy, :add_text, :add_signature, :download ]
  after_action :verify_authorized, except: :index
  after_action :verify_policy_scoped, only: :index

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
      redirect_to edit_pdf_document_path(@pdf_document), notice: "PDF uploaded successfully!"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @pdf_document
    # PDF editing page with tools
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

    @pdf_document.add_text_overlay(x, y, text, page)

    render json: {
      status: "success",
      message: "Text added successfully",
      pdf_status: @pdf_document.status
    }
  rescue => e
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

    @pdf_document.add_signature_overlay(x, y, signature_data, page)

    render json: {
      status: "success",
      message: "Signature added successfully"
    }
  rescue => e
    render json: {
      status: "error",
      message: e.message
    }, status: :unprocessable_entity
  end

  def download
    authorize @pdf_document
    if @pdf_document.processed_pdf.attached?
      send_data @pdf_document.processed_pdf.download,
                filename: @pdf_document.processed_pdf.filename.to_s,
                type: "application/pdf",
                disposition: "attachment"
    else
      redirect_back(fallback_location: @pdf_document, alert: "No processed PDF available")
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
