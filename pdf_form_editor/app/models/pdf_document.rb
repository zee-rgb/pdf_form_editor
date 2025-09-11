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

    Rails.logger.info "Processing text overlay for PDF #{id}: '#{text}' at (#{x}, #{y})"

    # Purge existing processed_pdf to prevent corruption
    processed_pdf.purge if processed_pdf.attached?

    # Always start from the original PDF to prevent cross-contamination
    input_temp = Tempfile.new([ "source_#{id}_#{Time.current.to_i}", ".pdf" ])
    File.open(input_temp.path, "wb") do |f|
      f.write(pdf_file.download)
    end

    doc = HexaPDF::Document.open(input_temp.path)
    page_obj = doc.pages[[ page, doc.pages.count - 1 ].min]
    x_pt, y_pt = normalize_pdf_coords(page_obj, x, y)

    Rails.logger.info "Converted coordinates: (#{x}, #{y}) -> (#{x_pt}, #{y_pt})"

    canvas = page_obj.canvas(type: :overlay)
    canvas.font("Helvetica", size: 12)
    canvas.text(text.to_s, at: [ x_pt, y_pt ])

    output_temp = Tempfile.new([ "filled_#{id}_#{Time.current.to_i}", ".pdf" ])
    doc.write(output_temp.path)

    # Create new attachment with unique filename and timestamp
    processed_pdf.attach(
      io: File.open(output_temp.path),
      filename: "filled_#{id}_#{Time.current.to_i}_#{pdf_file.filename}",
      content_type: "application/pdf"
    )

    input_temp.close
    output_temp.close
    update(status: :completed)

    Rails.logger.info "Created new processed_pdf for PDF #{id}: blob_id #{processed_pdf.blob.id}"
  rescue => e
    Rails.logger.error "Error in add_text_overlay for PDF #{id}: #{e.message}"
    update(status: :error)
    raise e
  end

  def add_signature_overlay(x, y, signature_data, page = 0)
    return unless pdf_file.attached?

    # Purge existing processed_pdf to prevent corruption
    processed_pdf.purge if processed_pdf.attached?

    input_temp = Tempfile.new([ "source_#{id}", ".pdf" ])
    File.open(input_temp.path, "wb") do |f|
      f.write(pdf_file.download)  # Always start from original
    end

    doc = HexaPDF::Document.open(input_temp.path)

    # Decode base64 signature image
    image_data = Base64.decode64(signature_data.to_s.split(",")[1].to_s)

    # Create temporary image file
    temp_image = Tempfile.new([ "signature_#{id}", ".png" ])
    temp_image.binmode
    temp_image.write(image_data)
    temp_image.rewind

    page_obj = doc.pages[[ page, doc.pages.count - 1 ].min]
    x_pt, y_pt = normalize_pdf_coords(page_obj, x, y)
    canvas = page_obj.canvas(type: :overlay)
    canvas.image(temp_image.path, at: [ x_pt, y_pt ], width: 150, height: 50)

    output_temp = Tempfile.new([ "signed_#{id}", ".pdf" ])
    doc.write(output_temp.path)

    # Create new attachment with unique filename
    processed_pdf.attach(
      io: File.open(output_temp.path),
      filename: "signed_#{id}_#{Time.current.to_i}_#{pdf_file.filename}",
      content_type: "application/pdf"
    )

    input_temp.close
    temp_image.close
    output_temp.close
    update(status: :completed)

    Rails.logger.info "Created new processed_pdf for PDF #{id}: blob_id #{processed_pdf.blob.id}"
  rescue => e
    update(status: :error)
    Rails.logger.error "Error adding signature: #{e.message}"
  end

  def add_multiple_overlays(elements)
    return unless pdf_file.attached?

    Rails.logger.info "Processing #{elements.length} overlays for PDF #{id}"
    processed_pdf.purge if processed_pdf.attached?

    input_temp = Tempfile.new([ "source_#{id}_#{Time.current.to_i}", ".pdf" ])
    File.open(input_temp.path, "wb") do |f|
      f.write(pdf_file.download)
    end

    doc = HexaPDF::Document.open(input_temp.path)
    page_obj = doc.pages[0] # Use first page for now

    elements.each_with_index do |element, index|
      # Handle both string and symbol keys
      element = element.with_indifferent_access if element.is_a?(Hash)

      x = element["x"].to_f
      y = element["y"].to_f
      page = element["page"]&.to_i || 0

      Rails.logger.info "Element #{index + 1}: Raw element data: #{element.inspect}"
      Rails.logger.info "Element #{index + 1}: Extracted coordinates: x=#{x}, y=#{y}, page=#{page}"

      # Use the correct page
      page_obj = doc.pages[[ page, doc.pages.count - 1 ].min]
      x_pt, y_pt = normalize_pdf_coords(page_obj, x, y)

      Rails.logger.info "Element #{index + 1}: Input coordinates: (#{x}, #{y}), PDF dimensions: #{page_obj.box(:media).width.to_f}x#{page_obj.box(:media).height.to_f}"
      Rails.logger.info "Element #{index + 1}: Converted coordinates: (#{x_pt}, #{y_pt})"

      canvas = page_obj.canvas(type: :overlay)

      if element["type"] == "text"
        canvas.font("Helvetica", size: 12)
        canvas.text(element["content"].to_s, at: [ x_pt, y_pt ])
        Rails.logger.info "Added text: '#{element["content"]}' at (#{x_pt}, #{y_pt})"
      elsif element["type"] == "signature"
        # Handle signature - use the actual signature image data
        if element["signature_data"].present?
          begin
            # Decode base64 signature image
            image_data = Base64.decode64(element["signature_data"].to_s.split(",")[1].to_s)

            # Create temporary image file
            temp_image = Tempfile.new([ "signature_#{id}_#{index}", ".png" ])
            temp_image.binmode
            temp_image.write(image_data)
            temp_image.rewind

            # Add image to PDF
            canvas.image(temp_image.path, at: [ x_pt, y_pt ], width: 150, height: 50)
            temp_image.close
            Rails.logger.info "Added signature image at (#{x_pt}, #{y_pt})"
          rescue => e
            Rails.logger.error "Error processing signature image: #{e.message}"
            # Fallback to text
            canvas.font("Helvetica", size: 12)
            signature_text = element["content"] || "[SIGNATURE]"
            canvas.text(signature_text, at: [ x_pt, y_pt ])
            Rails.logger.info "Added signature text fallback: '#{signature_text}' at (#{x_pt}, #{y_pt})"
          end
        else
          # Fallback to text if no image data
          canvas.font("Helvetica", size: 12)
          signature_text = element["content"] || "[SIGNATURE]"
          canvas.text(signature_text, at: [ x_pt, y_pt ])
          Rails.logger.info "Added signature text: '#{signature_text}' at (#{x_pt}, #{y_pt})"
        end
      end
    end

    output_temp = Tempfile.new([ "filled_#{id}_#{Time.current.to_i}", ".pdf" ])
    doc.write(output_temp.path)

    processed_pdf.attach(
      io: File.open(output_temp.path),
      filename: "filled_#{id}_#{Time.current.to_i}_#{pdf_file.filename}",
      content_type: "application/pdf"
    )

    input_temp.close
    output_temp.close
    update(status: :completed)

    Rails.logger.info "Created new processed_pdf for PDF #{id}: blob_id #{processed_pdf.blob.id}"
  rescue => e
    Rails.logger.error "Error in add_multiple_overlays for PDF #{id}: #{e.message}"
    update(status: :error)
    raise e
  end

  private

  # Convert UI coordinates to PDF points
  # Accepts:
  #  - absolute pixels/points (x,y > 100): assumes top-left origin, converts y to bottom-left
  #  - percentages 0..100 (from overlay): converts to points with top-left origin -> bottom-left
  #  - ratios 0..1: treats as percent fractions
  def normalize_pdf_coords(page, x, y)
    media_box = page.box(:media)
    width = media_box.width.to_f
    height = media_box.height.to_f

    xf = x.to_f
    yf = y.to_f

    Rails.logger.info "Input coordinates: (#{xf}, #{yf}), PDF dimensions: #{width}x#{height}"

    if xf <= 1 && yf <= 1
      # 0..1 ratios
      x_pt = width * xf
      y_pt = height * (1.0 - yf)
    elsif xf <= 100 && yf <= 100
      # 0..100 percentages from top-left origin (web) to bottom-left origin (PDF)
      x_pt = width * (xf / 100.0)
      # Convert from top-left origin to bottom-left origin
      y_pt = height * (1.0 - (yf / 100.0))
    else
      # Assume already in points/pixels from top-left, convert Y
      x_pt = xf
      y_pt = height - yf
    end

    Rails.logger.info "Converted coordinates: (#{x_pt}, #{y_pt})"
    [ x_pt, y_pt ]
  end
end
