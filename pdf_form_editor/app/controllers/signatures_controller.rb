class SignaturesController < ApplicationController
  before_action :authenticate_user!

  # Generates a signature preview image based on text and font
  def preview
    content = params[:content]
    font = params[:font] || "Dancing Script"
    size = params[:size]&.to_i || 40

    if content.blank?
      render json: { error: "Content cannot be blank" }, status: :unprocessable_entity
      return
    end

    service = SignatureService.new(content, { font: font, size: size })
    signature_image = service.generate_signature_image

    if signature_image
      render json: { image: signature_image }
    else
      render json: { error: "Failed to generate signature preview" }, status: :unprocessable_entity
    end
  rescue => e
    Rails.logger.error "Error generating signature preview: #{e.message}"
    render json: { error: e.message }, status: :unprocessable_entity
  end
end
