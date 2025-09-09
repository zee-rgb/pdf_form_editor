class PdfDocument < ApplicationRecord
  belongs_to :user

  has_one_attached :pdf_file
  has_one_attached :processed_pdf

  validates :title, presence: true
  validates :pdf_file, presence: true

  enum :status, {
    uploaded: 0,
    processing: 1,
    completed: 2,
    error: 3
  }

  def add_text_overlay(x, y, text, page = 0)
    return unless pdf_file.attached?

    temp_file = Tempfile.new([ "original", ".pdf" ])
    File.open(temp_file.path, "wb") do |file|
      file.write(pdf_file.download)
    end

    doc = HexaPDF::Document.open(temp_file.path)
    canvas = doc.pages[page].canvas(type: :overlay)
    canvas.font("Helvetica", size: 12)
    canvas.text(text, at: [ x, y ])

    output_file = Tempfile.new([ "filled", ".pdf" ])
    doc.write(output_file.path)

    processed_pdf.attach(
      io: File.open(output_file.path),
      filename: "filled_#{pdf_file.filename}",
      content_type: "application/pdf"
    )

    temp_file.close
    output_file.close
    update(status: :completed)
  end

  def add_signature_overlay(x, y, signature_data, page = 0)
    return unless pdf_file.attached?

    temp_file = Tempfile.new([ "original", ".pdf" ])
    File.open(temp_file.path, "wb") do |file|
      file.write(pdf_file.download)
    end

    doc = HexaPDF::Document.open(temp_file.path)

    # Decode base64 signature image
    image_data = Base64.decode64(signature_data.split(",")[1])

    # Create temporary image file
    temp_image = Tempfile.new([ "signature", ".png" ])
    temp_image.binmode
    temp_image.write(image_data)
    temp_image.rewind

    canvas = doc.pages[page].canvas(type: :overlay)
    canvas.image(temp_image.path, at: [ x, y ], width: 150, height: 50)

    output_file = Tempfile.new([ "signed", ".pdf" ])
    doc.write(output_file.path)

    processed_pdf.attach(
      io: File.open(output_file.path),
      filename: "signed_#{pdf_file.filename}",
      content_type: "application/pdf"
    )

    temp_file.close
    temp_image.close
    output_file.close
    update(status: :completed)
  rescue => e
    update(status: :error)
    Rails.logger.error "Error adding signature: #{e.message}"
  end
end
