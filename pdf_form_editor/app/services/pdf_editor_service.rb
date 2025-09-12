require "hexapdf"
require "tempfile"
require "base64"

class PdfEditorService
  # Service for PDF document manipulation using HexaPDF

  def initialize(pdf_document)
    @pdf_document = pdf_document
  end

  def add_text(x, y, text, page = 0, options = {})
    process_pdf do |doc, pages|
      page_obj = pages[[ page, pages.count - 1 ].min]
      x_pt, y_pt = normalize_coordinates(page_obj, x, y)

      # Create transparent box behind text for better visibility
      canvas = page_obj.canvas(type: :overlay)
      font = options[:font] || "Helvetica"
      size = options[:font_size] || 12

      # Calculate text dimensions for background
      canvas.font(font, size: size)
      text_width = canvas.text_width(text.to_s)
      padding = size * 0.3 # 30% padding around text

      # Add slightly transparent white background box for better visibility
      canvas.save_graphics_state
      canvas.opacity(fill_alpha: 0.65)
      canvas.fill_color("white")
      canvas.rectangle(x_pt - padding, y_pt - padding,
                      text_width + (padding * 2), size + (padding * 2))
      canvas.fill
      canvas.restore_graphics_state

      # Draw text on top
      canvas.fill_color("black")
      canvas.font(font, size: size)
      canvas.text(text.to_s, at: [ x_pt, y_pt ])

      # Add to overlay elements for tracking
      @pdf_document.add_text_element(x, y, text) if options[:track]
    end
  end

  def add_signature(x, y, content_or_data, page = 0, options = {})
    process_pdf do |doc, pages|
      page_obj = pages[[ page, pages.count - 1 ].min]
      x_pt, y_pt = normalize_coordinates(page_obj, x, y)

      if content_or_data.to_s.start_with?("data:")
        # It's base64 image data
        add_signature_image(doc, page_obj, x_pt, y_pt, content_or_data)
      else
        # It's text content for a signature
        font = options[:font] || "Helvetica"
        add_signature_text(doc, page_obj, x_pt, y_pt, content_or_data, font)
      end

      # Add to overlay elements for tracking
      if options[:track]
        @pdf_document.add_signature_element(x, y, content_or_data, options[:font])
      end
    end
  end

  def apply_all_elements
    # Apply all saved overlay elements to the PDF
    return false unless @pdf_document.pdf_file.attached?
    return false unless @pdf_document.overlay_elements.present?

    process_pdf do |doc, pages|
      @pdf_document.overlay_elements.each do |element|
        type = element["type"]
        x = element["x"].to_f
        y = element["y"].to_f
        page = element["page"] || 0
        page_obj = pages[[ page, pages.count - 1 ].min]
        x_pt, y_pt = normalize_coordinates(page_obj, x, y)

        if type == "text"
          canvas = page_obj.canvas(type: :overlay)
          font = "Helvetica"
          size = 12
          text = element["content"].to_s

          # Calculate text dimensions for background
          canvas.font(font, size: size)
          text_width = canvas.text_width(text)
          padding = size * 0.3 # 30% padding around text

          # Add slightly transparent white background box for better visibility
          canvas.save_graphics_state
          canvas.opacity(fill_alpha: 0.65)
          canvas.fill_color("white")
          canvas.rectangle(x_pt - padding, y_pt - padding,
                          text_width + (padding * 2), size + (padding * 2))
          canvas.fill
          canvas.restore_graphics_state

          # Draw text on top
          canvas.fill_color("black")
          canvas.font(font, size: size)
          canvas.text(text, at: [ x_pt, y_pt ])

        elsif type == "signature"
          font = element["font"] || "Helvetica"
          canvas = page_obj.canvas(type: :overlay)
          text = element["content"].to_s
          size = 16

          # Calculate text dimensions for background
          canvas.font(font, size: size)
          text_width = canvas.text_width(text)
          padding = size * 0.5 # 50% padding for signature

          # Add slightly transparent white background box for better visibility
          canvas.save_graphics_state
          canvas.opacity(fill_alpha: 0.65)
          canvas.fill_color("white")
          canvas.rectangle(x_pt - padding, y_pt - padding,
                          text_width + (padding * 2), size + (padding * 2))
          canvas.fill
          canvas.restore_graphics_state

          # Draw text on top
          canvas.fill_color("black")
          canvas.font(font, size: size)
          canvas.text(text, at: [ x_pt, y_pt ])
        end
      end
    end

    true
  end

  private

  def add_signature_image(doc, page, x, y, signature_data)
    # Extract the actual image data from the data URL
    image_data = Base64.decode64(signature_data.to_s.split(",")[1].to_s)

    # Create temporary image file
    temp_image = Tempfile.new([ "signature_#{@pdf_document.id}", ".png" ])
    temp_image.binmode
    temp_image.write(image_data)
    temp_image.rewind

    # Add image to PDF
    canvas = page.canvas(type: :overlay)
    canvas.image(temp_image.path, at: [ x, y ], width: 150, height: 50)
    temp_image.close
  end

  def add_signature_text(doc, page, x, y, text, font)
    canvas = page.canvas(type: :overlay)
    canvas.font(font, size: 16)
    canvas.text(text, at: [ x, y ])
  end

  def process_pdf
    return false unless @pdf_document.pdf_file.attached?

    @pdf_document.processed_pdf.purge if @pdf_document.processed_pdf.attached?

    input_temp = Tempfile.new([ "source_#{@pdf_document.id}_#{Time.current.to_i}", ".pdf" ])
    File.open(input_temp.path, "wb") do |f|
      f.write(@pdf_document.pdf_file.download)
    end

    doc = HexaPDF::Document.open(input_temp.path)
    yield(doc, doc.pages)

    output_temp = Tempfile.new([ "processed_#{@pdf_document.id}_#{Time.current.to_i}", ".pdf" ])
    doc.write(output_temp.path)

    @pdf_document.processed_pdf.attach(
      io: File.open(output_temp.path),
      filename: "processed_#{@pdf_document.id}_#{Time.current.to_i}_#{@pdf_document.pdf_file.filename}",
      content_type: "application/pdf"
    )

    input_temp.close
    output_temp.close
    @pdf_document.update(status: :completed)

    true
  rescue => e
    Rails.logger.error "Error processing PDF #{@pdf_document.id}: #{e.message}"
    @pdf_document.update(status: :error)
    false
  end

  # Convert UI coordinates to PDF points
  # Accepts:
  #  - percentages 0..100 (from overlay): converts to points with top-left origin -> bottom-left
  #  - ratios 0..1: treats as percent fractions
  #  - absolute pixels/points (x,y > 100): assumes top-left origin, converts y to bottom-left
  def normalize_coordinates(page, x, y)
    media_box = page.box(:media)
    width = media_box.width.to_f
    height = media_box.height.to_f

    xf = x.to_f
    yf = y.to_f

    if xf <= 1 && yf <= 1
      # 0..1 ratios
      x_pt = width * xf
      y_pt = height * (1.0 - yf)
    elsif xf <= 100 && yf <= 100
      # 0..100 percentages - convert from web top-left to PDF bottom-left
      x_pt = width * (xf / 100.0)
      y_pt = height * (1.0 - (yf / 100.0)) # Invert Y for PDF coordinate system
    else
      # Assume already in points/pixels from top-left, convert Y
      x_pt = xf
      y_pt = height - yf
    end

    [ x_pt, y_pt ]
  end
end
