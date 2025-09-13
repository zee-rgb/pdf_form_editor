class PdfDocument < ApplicationRecord
  has_one_attached :pdf_file
  has_one_attached :processed_pdf
  belongs_to :user
  serialize :overlay_elements, coder: JSON

  validates :title, presence: true
  validates :pdf_file, presence: true

  # Define enum for status using Rails enum functionality
  enum :status, { uploaded: 0, processing: 1, completed: 2, error: 3 }

  # For backward compatibility with existing code that expects the old STATUSES constant
  STATUSES = { uploaded: 0, processing: 1, completed: 2, error: 3 }.freeze

  # Class-level helper to get the hash, mimicking ActiveRecord's enum behavior
  def self.statuses
    { "uploaded" => 0, "processing" => 1, "completed" => 2, "error" => 3 }
  end

  # Add a text element to the PDF
  def add_text_element(x, y, content)
    elements = overlay_elements || []

    # Use the exact coordinates provided by the user
    # Ensure the coordinates stay within reasonable bounds (e.g., 0-100)
    adjusted_x = x.clamp(0, 100)
    adjusted_y = y.clamp(0, 100)

    element = {
      id: elements.size,
      type: "text",
      content: content,
      x: adjusted_x,
      y: adjusted_y
    }

    # Add the new element to the array
    elements << element

    # Save the updated elements
    self.overlay_elements = elements
    save

    # Return the added element
    element
  end

  # Alias for add_text_element to match expected method name in tests
  def add_text_overlay(x, y, text, page = 0)
    add_text_element(x, y, text)
  end

  # Add a signature to the PDF
  def add_signature_element(x, y, content, font = nil)
    elements = overlay_elements || []

    # Ensure the coordinates stay within reasonable bounds
    adjusted_x = x.clamp(0, 100)
    adjusted_y = y.clamp(0, 100)

    element = {
      id: elements.size,
      type: "signature",
      content: content,
      font: font,
      x: adjusted_x,
      y: adjusted_y
    }

    # Add the new element to the array
    elements << element

    # Save the updated elements
    self.overlay_elements = elements
    if save
      Rails.logger.info "Created new signature element for PDF #{id}"
      true
    else
      Rails.logger.error "Failed to add signature to PDF #{id}"
      false
    end
  end

  # Alias for add_signature_element to match expected method name in tests
  def add_signature_overlay(x, y, signature_data, page = 0)
    add_signature_element(x, y, signature_data)
  end

  # Apply overlay elements to the PDF using Prawn
  def apply_all_elements
    # Create a unique logger for this run to make debugging easier
    run_logger = Logger.new(Rails.root.join("log", "pdf_apply_#{id}_#{Time.now.to_i}.log"))
    run_logger.info "START: Applying overlay elements to PDF #{id} using Prawn"

    # Check if PDF file is attached
    unless pdf_file.attached?
      run_logger.error "FAIL: No PDF file attached to document #{id}"
      update(status: :error)
      return false
    end

    # Check if overlay elements exist
    if overlay_elements.blank? || overlay_elements.empty?
      run_logger.warn "SKIP: No overlay elements for PDF #{id}, nothing to apply. This is a success."
      # Still consider this a success since there's nothing to do
      return true
    end

    begin
      require "prawn"
      require "prawn/templates"

      # Create working directory with timestamp for unique files
      timestamp = Time.now.to_i
      work_dir = Rails.root.join("tmp", "pdf_work_#{timestamp}")
      FileUtils.mkdir_p(work_dir)
      Rails.logger.info "Created work directory: #{work_dir}"

      # Create public verification directory
      verification_dir = Rails.root.join("public", "pdf_verification")
      FileUtils.mkdir_p(verification_dir)

      # Download the original PDF to a file - MUST be a file for Prawn template
      input_path = work_dir.join("original-#{id}.pdf")
      original_data = pdf_file.download
      File.binwrite(input_path, original_data)
      Rails.logger.info "Downloaded original PDF (#{original_data.bytesize} bytes) to: #{input_path}"

      # Also save a copy of original PDF for verification
      original_copy_path = verification_dir.join("original-#{id}-#{timestamp}.pdf")
      File.binwrite(original_copy_path, original_data)

      # Set output path
      output_path = work_dir.join("processed-#{id}-#{timestamp}.pdf")

      # Create a new Prawn::Document with the existing PDF as template
      Rails.logger.info "Creating Prawn document using template: #{input_path}"
      pdf = Prawn::Document.new(template: input_path.to_s)

      # Add a visible marker to confirm PDF is being modified - RED CIRCLE
      pdf.fill_color "FF0000" # Red
      pdf.circle [ 20, 20 ], 5
      pdf.fill

      # Add a marker with text for absolute confirmation
      pdf.fill_color "000000" # Black
      pdf.font_size 6
      pdf.text_box "MODIFIED BY PDF EDITOR", at: [ 30, 20 ]

      # Process overlay elements
      Rails.logger.info "Processing #{overlay_elements.size} overlay elements"
      overlay_elements.each_with_index do |element, index|
        # Skip placeholder elements
        next if element["type"] == "placeholder"

        # Get content and position
        content = element["content"].to_s
        x_pct = element["x"].to_f
        y_pct = element["y"].to_f

        # Convert percentage to points (assuming page 1 for now)
        # Prawn uses coordinate system with origin at bottom left
        # Map coordinates from web view (top-left origin) to PDF (bottom-left origin)
        # and adjust to match form fields more precisely

        # Dynamic positioning adjustments based on element type
        if element["type"] == "signature"
          # X coordinate mapping for signatures - signatures need different offset
          x = (pdf.bounds.width * (x_pct / 100.0)) - 5

          # Y coordinate mapping for signatures
          y_correction = 30 # Lower y-correction for signatures
          y = pdf.bounds.height * (1 - (y_pct / 100.0)) + y_correction
        else
          # X coordinate mapping for regular text - text needs different offset
          x = (pdf.bounds.width * (x_pct / 100.0)) - 20

          # Y coordinate mapping for text
          y_correction = 45 # Higher y-correction for text
          y = pdf.bounds.height * (1 - (y_pct / 100.0)) + y_correction
        end

        Rails.logger.info "Adding element #{index+1}: '#{content}' at (#{x}, #{y})"

        # Draw text with visible formatting based on element type
        if element["type"] == "signature"
          # Special styling for signatures - clean black text without borders or underlines
          pdf.fill_color "000000" # Black

          # Map web fonts to PDF fonts specifically designed for signatures
          # Use various script/handwriting fonts in Prawn for better signature appearance
          font_name = element["font"] || "Dancing Script"

          # Custom rendering approach to prevent overlines
          case font_name
          when "Dancing Script"
            # Use Courier-Oblique for more hand-written feel
            pdf.font("Courier-Oblique") do
              pdf.text_box content,
                at: [ x, y ],
                size: 16,
                overflow: :shrink_to_fit,
                min_font_size: 8
            end
          when "Great Vibes"
            # Use Helvetica-Bold-Italic for fancier signature
            pdf.font("Helvetica-BoldOblique") do
              pdf.text_box content,
                at: [ x, y ],
                size: 17,
                overflow: :shrink_to_fit,
                min_font_size: 8
            end
          when "Allura"
            # Use Times-BoldItalic for elegant signature
            pdf.font("Times-BoldItalic") do
              pdf.text_box content,
                at: [ x, y ],
                size: 16,
                overflow: :shrink_to_fit,
                min_font_size: 8
            end
          else
            # Default to Times-Italic for any other font
            pdf.font("Times-Italic") do
              pdf.text_box content,
                at: [ x, y ],
                size: 16,
                overflow: :shrink_to_fit,
                min_font_size: 8
            end
          end
        else
          # Regular text - plain black text without border or background
          pdf.fill_color "000000" # Black
          pdf.text_box content, at: [ x, y ], size: 12
        end

        # Reset colors
        pdf.fill_color "000000" # Black
        pdf.stroke_color "000000" # Black
      end

      # Save the modified PDF
      Rails.logger.info "Saving modified PDF to #{output_path}"
      pdf.render_file(output_path)

      # Verify the output file exists and has content
      unless File.exist?(output_path)
        Rails.logger.error "Failed to create output PDF at #{output_path}"
        return false
      end

      # Check output file size
      output_size = File.size(output_path)
      Rails.logger.info "Created processed PDF: #{output_size} bytes"

      # Size sanity check
      if output_size < 1000
        Rails.logger.error "Generated PDF is suspiciously small (#{output_size} bytes)"
        return false
      end

      # Save a copy for verification
      verification_file = verification_dir.join("processed-#{id}-#{timestamp}.pdf")
      FileUtils.cp(output_path, verification_file)
      Rails.logger.info "Created verification copy at: #{verification_file}"

      # Purge any previous processed PDF attachment
      if processed_pdf.attached?
        Rails.logger.info "Purging existing processed PDF attachment"
        processed_pdf.purge
      end

      # Attach the new processed PDF to the model
      run_logger.info "Attaching new processed PDF from #{output_path}"
      processed_pdf.attach(
        io: File.open(output_path, "rb"),
        filename: "#{title.parameterize}_processed.pdf",
        content_type: "application/pdf"
      )

      # Verify attachment was successful
      unless processed_pdf.attached?
        run_logger.error "FAIL: Failed to attach processed PDF after generation."
        update(status: :error)
        return false
      end

      # Check attachment size
      Rails.logger.info "Successfully attached processed PDF: #{processed_pdf.filename} (#{processed_pdf.byte_size} bytes)"
      if processed_pdf.byte_size < 100
        Rails.logger.error "Processed PDF attachment is too small (#{processed_pdf.byte_size} bytes)"
        return false
      end

      # Update status and return success
      update(status: :processed)
      run_logger.info "SUCCESS: Successfully applied all elements to PDF #{id}"
      true
    rescue => e
      run_logger.error "CRASH: Error applying PDF elements: #{e.message}"
      run_logger.error e.backtrace.join("\n")
      update(status: :error)
      false
    end
  end
end
