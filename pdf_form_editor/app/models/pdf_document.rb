require "combine_pdf"

class PdfDocument < ApplicationRecord
  belongs_to :user

  has_one_attached :pdf_file
  has_one_attached :processed_pdf

  validates :title, presence: true
  validates :pdf_file, presence: true

  # Ensure overlay_elements is always serialized as JSON
  serialize :overlay_elements, coder: JSON

  # Make sure overlay_elements is always an array, even if nil
  def overlay_elements
    super || []
  end

  enum :status, {
    uploaded: 0,
    processing: 1,
    completed: 2,
    error: 3
  }

  def add_text_overlay(x, y, content, page = 0, options = {})
    # Simply add text element to the overlay_elements array
    # This ensures the element is always tracked, even if there are PDF rendering issues
    Rails.logger.info "Adding text overlay at x=#{x}, y=#{y}, content=#{content}"
    add_text_element(x, y, content)
    true
  end

  def add_signature_overlay(x, y, signature_data, page = 0, options = {})
    return unless pdf_file.attached?

    Rails.logger.info "Adding signature overlay to PDF #{id}"

    service = PdfEditorService.new(self)
    track = options.fetch(:track, true)
    font = options[:font] || "Dancing Script"

    if service.add_signature(x, y, signature_data, page, {
        track: track,
        font: font
      })
      Rails.logger.info "Created new processed_pdf with signature for PDF #{id}"
      true
    else
      Rails.logger.error "Failed to add signature to PDF #{id}"
      false
    end
  end

  # Apply overlay elements to the PDF using combine_pdf
  def apply_all_elements
    Rails.logger.info "Starting apply_all_elements for PDF #{id}"
    Rails.logger.info "Overlay elements count: #{overlay_elements&.size || 0}"

    # Check if PDF file is attached
    unless pdf_file.attached?
      Rails.logger.error "No PDF file attached to document #{id}"
      return false
    end

    # Log information about the PDF file
    Rails.logger.info "PDF file: #{pdf_file.filename}, Size: #{pdf_file.byte_size} bytes, Content type: #{pdf_file.content_type}"

    # Check if overlay elements exist
    if overlay_elements.blank? || overlay_elements.empty?
      Rails.logger.warn "No overlay elements for PDF #{id}, nothing to apply"
      # Still consider this a success since there's nothing to do
      return true
    end

    begin
      # Log details about the elements that will be applied
      overlay_elements.each_with_index do |element, index|
        Rails.logger.info "Element #{index}: type=#{element['type']}, content=#{element['content']}, x=#{element['x']}, y=#{element['y']}"
      end

      Rails.logger.info "Creating temp file for PDF processing"
      # Create a temporary file for the processed PDF
      pdf_data = nil
      tempfile = Tempfile.create([ "processed_", ".pdf" ], binmode: true)

      begin
        # Load the PDF file
        Rails.logger.info "Loading PDF file for document #{id}"
        pdf_content = pdf_file.download
        Rails.logger.info "Downloaded #{pdf_content.size} bytes of PDF data"

        pdf = CombinePDF.parse(pdf_content)
        Rails.logger.info "Successfully parsed PDF with #{pdf.pages.size} pages"

        # Process each overlay element
        successful_elements = 0
        failed_elements = 0

        overlay_elements.each do |element|
          begin
            Rails.logger.info "Processing element: #{element.inspect}"

            page_number = element["page"].to_i rescue 0 # Default to first page
            page_index = page_number

            # Make sure we have a valid page
            if pdf.pages[page_index].nil?
              Rails.logger.warn "Invalid page index #{page_index}, defaulting to first page"
              page_index = 0
            end

            page = pdf.pages[page_index]

            case element["type"]
            when "text"
              add_text_to_page(page, element)
              successful_elements += 1
            when "signature"
              add_signature_to_page(page, element)
              successful_elements += 1
            when "placeholder"
              Rails.logger.info "Skipping placeholder element"
            else
              Rails.logger.warn "Unknown element type: #{element['type']}"
              failed_elements += 1
            end
          rescue => e
            failed_elements += 1
            Rails.logger.error "Error processing element #{element['id'] || 'unknown'}: #{e.message}"
            Rails.logger.error e.backtrace.join("\n")
            # Continue with next element instead of failing the entire process
            next
          end
        end

        Rails.logger.info "Elements processed: #{successful_elements} successful, #{failed_elements} failed"

        # Save the processed PDF
        Rails.logger.info "Saving processed PDF to temp file"
        pdf_data = pdf.to_pdf
        tempfile.write(pdf_data)
        tempfile.flush
        tempfile.rewind

        # Get the size of the generated PDF for debugging
        tempfile_size = File.size(tempfile.path)
        Rails.logger.info "Generated PDF size: #{tempfile_size} bytes"

        # Attach the processed PDF
        if processed_pdf.attached?
          Rails.logger.info "Purging existing processed PDF"
          processed_pdf.purge
        end

        Rails.logger.info "Attaching new processed PDF"
        processed_pdf.attach(
          io: tempfile,
          filename: "#{title.parameterize}_processed.pdf",
          content_type: "application/pdf"
        )

        # Verify the attachment was successful
        if processed_pdf.attached?
          Rails.logger.info "Successfully attached processed PDF: #{processed_pdf.filename}, Size: #{processed_pdf.byte_size} bytes"
        else
          Rails.logger.error "Failed to attach processed PDF"
          return false
        end

        Rails.logger.info "Successfully applied all elements to PDF #{id}"
        true
      ensure
        # Clean up temporary file
        tempfile.close
        tempfile.unlink
      end
    rescue => e
      Rails.logger.error "Error applying PDF elements: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      false
    end
  end

  private

  # Add text element to a PDF page
  def add_text_to_page(page, element)
    begin
      # Calculate position in PDF coordinates
      x = (element["x"].to_f / 100.0) * page.width
      y = ((100 - element["y"].to_f) / 100.0) * page.height  # Invert Y since PDF coords start from bottom

      # Create text object
      text = element["content"].to_s

      # Log more details for debugging
      Rails.logger.info "Adding text '#{text}' at page coordinates: x=#{x}, y=#{y}"
      Rails.logger.info "Original percentage coordinates: x=#{element['x']}%, y=#{element['y']}%"

      # Use direct text insertion instead of annotation
      # Create text options with the font and size
      text_options = {
        font: :Helvetica,
        size: 12,
        color: [ 0, 0, 0 ] # Black
      }

      # Insert text directly on the page at the specified coordinates
      page.text(text, x, y, text_options)

      # Also add a backup method using annotations (for compatibility)
      width = text.length * 8
      height = 15

      page.annotate(
        text,
        x: x, y: y,
        width: width, height: height,
        options: {
          FontSize: 12,
          TextAlign: :left,
          TextColor: [ 0, 0, 0 ]
        }
      )

      Rails.logger.info "Added text '#{text[0..20]}...' to PDF at (#{x}, #{y})"
    rescue => e
      Rails.logger.error "Error adding text to page: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
    end
  end

  # Add signature element to a PDF page
  def add_signature_to_page(page, element)
    begin
      # Calculate position in PDF coordinates
      x = (element["x"].to_f / 100.0) * page.width
      y = ((100 - element["y"].to_f) / 100.0) * page.height  # Invert Y since PDF coords start from bottom

      # Create text object with signature styling
      text = element["content"].to_s
      font = element["font"] || "Dancing Script"

      # Log more details for debugging
      Rails.logger.info "Adding signature '#{text}' at page coordinates: x=#{x}, y=#{y}"
      Rails.logger.info "Original percentage coordinates: x=#{element['x']}%, y=#{element['y']}%"
      Rails.logger.info "Font: #{font}, Page dimensions: #{page.width}x#{page.height}"

      # Since we can't actually use handwriting fonts directly in CombinePDF,
      # use a distinctive styling instead (blue, italic, larger)
      text_options = {
        font: :Helvetica_Oblique, # Use italic font
        size: 16,                 # Larger font size
        color: [ 0, 0, 0.7 ]        # Blue color
      }

      # Insert text directly on the page at the specified coordinates
      page.text(text, x, y, text_options)

      # Draw an underline to make it look more like a signature
      underline_y = y - 2  # Slightly below the text
      line_width = text.length * 9

      # Add a line using the graphics operator
      page.graphic_state.save
      page.graphic_state.stroke_color = [ 0, 0, 0.7 ]
      page.graphic_state.line_width = 0.5
      page.add_content("#{x} #{underline_y} m #{x + line_width} #{underline_y} l S")
      page.graphic_state.restore

      # Also add a backup method using annotations
      width = text.length * 10
      height = 20

      page.annotate(
        text,
        x: x, y: y,
        width: width, height: height,
        options: {
          FontSize: 16,
          TextAlign: :left,
          TextColor: [ 0, 0, 0.7 ]
        }
      )

      Rails.logger.info "Added signature '#{text[0..20]}...' to PDF at (#{x}, #{y})"
    rescue => e
      Rails.logger.error "Error adding signature to page: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
    end
  end

  def add_text_element(x, y, content)
    elements = overlay_elements || []

    # Use the exact coordinates provided by the user
    # Ensure the coordinates stay within reasonable bounds (e.g., 0-100)
    adjusted_x = x.clamp(0, 100)
    adjusted_y = y.clamp(0, 100)

    # Create element with a unique ID for tracking
    elements << {
      "type" => "text",
      "x" => adjusted_x,
      "y" => adjusted_y,
      "content" => content,
      "id" => "text_#{Time.current.to_i}_#{SecureRandom.hex(4)}",
      "created_at" => Time.current
    }

    # Update and save elements
    update!(overlay_elements: elements)
  end

  def add_signature_element(x, y, content, font = "Dancing Script")
    elements = overlay_elements || []

    # Use the exact coordinates provided by the user
    # Ensure the coordinates stay within reasonable bounds (e.g., 0-100)
    adjusted_x = x.clamp(0, 100)
    adjusted_y = y.clamp(0, 100)

    # Create element with a unique ID for tracking
    elements << {
      "type" => "signature",
      "x" => adjusted_x,
      "y" => adjusted_y,
      "content" => content,
      "font" => font,
      "id" => "signature_#{Time.current.to_i}_#{SecureRandom.hex(4)}",
      "created_at" => Time.current
    }
    update!(overlay_elements: elements)
  end

  def remove_element(index)
    elements = overlay_elements || []
    elements.delete_at(index) if index >= 0 && index < elements.length
    update!(overlay_elements: elements)
  end

  # Update the position of an element
  def update_element_position(index, x, y)
    elements = overlay_elements || []
    return false unless index >= 0 && index < elements.length

    element = elements[index]
    element["x"] = x
    element["y"] = y
    element["updated_at"] = Time.current
    elements[index] = element

    update!(overlay_elements: elements)
  end

  # Helper to get editor service instance
  def pdf_editor
    @pdf_editor ||= PdfEditorService.new(self)
  end
end
