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
  
  # Deduplicate overlay elements to prevent duplications
  def deduplicate_elements
    return if overlay_elements.blank?
    
    unique_elements = []
    seen_elements = {}
    
    # Process elements and keep only unique ones based on content and position
    overlay_elements.each do |element|
      # Create a unique key based on content and position
      key = "#{element['type']}_#{element['content']}_#{element['x']}_#{element['y']}"
      
      # Only keep the element if we haven't seen it before
      unless seen_elements[key]
        unique_elements << element
        seen_elements[key] = true
      end
    end
    
    # Update the document with deduplicated elements
    self.overlay_elements = unique_elements
    save
    
    # Return the deduplicated elements
    unique_elements
  end

  # Apply overlay elements to the PDF using Prawn
  def apply_all_elements
    Rails.logger.info "Starting apply_all_elements for PDF #{id}"
    run_logger = Rails.logger
    
    # Update status to processing
    update_column(:status, :processing) if status != "processing"

    # Check if PDF file exists
    unless pdf_file.attached?
      run_logger.error "No PDF file attached to document #{id}"
      update_column(:status, :error)
      return false
    end

    # Check if overlay elements exist
    if overlay_elements.blank? || overlay_elements.empty?
      run_logger.warn "SKIP: No overlay elements for PDF #{id}, nothing to apply. This is a success."
      # Still consider this a success since there's nothing to do
      update_column(:status, :uploaded) # Keep it as uploaded since no changes
      return true
    end
    
    # Deduplicate overlay elements first
    deduplicate_elements

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

        # Dynamic positioning adjustments based on element type and field positions
        if element["type"] == "signature"
          # Get any additional positioning info that might be in the element data
          field_name = element["field"] || ""
          
          # Adjust for specific fields if information exists
          if field_name.present?
            case field_name.downcase
            when /name/
              x = (pdf.bounds.width * 0.35)
              y = (pdf.bounds.height * 0.82)
            when /signature/
              x = (pdf.bounds.width * 0.40)
              y = (pdf.bounds.height * 0.20)
            when /date/
              x = (pdf.bounds.width * 0.80)
              y = (pdf.bounds.height * 0.20)
            else
              # Default positioning with improved offset
              x = (pdf.bounds.width * (x_pct / 100.0)) - 3
              y = pdf.bounds.height * (1 - (y_pct / 100.0)) + 40
            end
          else
            # Use exact percentage position with better calibration
            x = (pdf.bounds.width * (x_pct / 100.0)) - 3
            y = pdf.bounds.height * (1 - (y_pct / 100.0)) + 40
          end
        else
          # Get any additional positioning info that might be in the element data
          field_name = element["field"] || ""
          
          # Handle specific field types for text elements
          if field_name.present?
            case field_name.downcase
            when /name/
              x = (pdf.bounds.width * 0.40)
              y = (pdf.bounds.height * 0.82)
            when /email/
              x = (pdf.bounds.width * 0.40)
              y = (pdf.bounds.height * 0.78)
            when /address/
              x = (pdf.bounds.width * 0.40)
              y = (pdf.bounds.height * 0.70)
            when /city/
              x = (pdf.bounds.width * 0.40)
              y = (pdf.bounds.height * 0.64)
            when /state/
              x = (pdf.bounds.width * 0.28)
              y = (pdf.bounds.height * 0.60)
            when /zip/
              x = (pdf.bounds.width * 0.70)
              y = (pdf.bounds.height * 0.60)
            when /phone/
              x = (pdf.bounds.width * 0.40)
              y = (pdf.bounds.height * 0.74)
            else
              # Improved general positioning for text
              x = (pdf.bounds.width * (x_pct / 100.0)) - 10
              y = pdf.bounds.height * (1 - (y_pct / 100.0)) + 50
            end
          else
            # Improved general positioning for text
            x = (pdf.bounds.width * (x_pct / 100.0)) - 10
            y = pdf.bounds.height * (1 - (y_pct / 100.0)) + 50
          end
        end

        Rails.logger.info "Adding element #{index+1}: '#{content}' at (#{x}, #{y})"

        # Draw text with visible formatting based on element type
        if element["type"] == "signature"
          # Special styling for signatures - clean black text without borders or underlines
          pdf.fill_color "000000" # Black

          # Use proper cursive fonts for signatures
          # We need to embed custom fonts to match the web fonts exactly
          font_name = element["font"] || "Dancing Script"
          
          # First, register the custom fonts with Prawn
          pdf.font_families.update(
            "dancing-script" => {
              normal: "#{Rails.root.join('app', 'assets', 'fonts', 'DancingScript-Regular.ttf')}"
            },
            "great-vibes" => {
              normal: "#{Rails.root.join('app', 'assets', 'fonts', 'GreatVibes-Regular.ttf')}"
            },
            "allura" => {
              normal: "#{Rails.root.join('app', 'assets', 'fonts', 'Allura-Regular.ttf')}"
            }
          )
          
          # Use the exact fonts from the web interface
          case font_name
          when "Dancing Script"
            if File.exist?(Rails.root.join('app', 'assets', 'fonts', 'DancingScript-Regular.ttf'))
              pdf.font("dancing-script") do
                pdf.text_box content, 
                  at: [ x, y ],
                  size: 16,
                  overflow: :shrink_to_fit,
                  min_font_size: 8
              end
            else
              # Fallback if font file doesn't exist
              pdf.font("Times-Italic") do
                pdf.text_box content, 
                  at: [ x, y ],
                  size: 16,
                  overflow: :shrink_to_fit,
                  min_font_size: 8
              end
            end
          when "Great Vibes"
            if File.exist?(Rails.root.join('app', 'assets', 'fonts', 'GreatVibes-Regular.ttf'))
              pdf.font("great-vibes") do
                pdf.text_box content, 
                  at: [ x, y ],
                  size: 17,
                  overflow: :shrink_to_fit,
                  min_font_size: 8
              end
            else
              # Fallback if font file doesn't exist
              pdf.font("Times-Italic") do
                pdf.text_box content, 
                  at: [ x, y ],
                  size: 17,
                  overflow: :shrink_to_fit,
                  min_font_size: 8
              end
            end
          when "Allura"
            if File.exist?(Rails.root.join('app', 'assets', 'fonts', 'Allura-Regular.ttf'))
              pdf.font("allura") do
                pdf.text_box content, 
                  at: [ x, y ],
                  size: 16,
                  overflow: :shrink_to_fit,
                  min_font_size: 8
              end
            else
              # Fallback if font file doesn't exist
              pdf.font("Times-Italic") do
                pdf.text_box content, 
                  at: [ x, y ],
                  size: 16,
                  overflow: :shrink_to_fit,
                  min_font_size: 8
              end
            end
          else
            # Default fallback
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

      # Save the processed PDF to ActiveStorage
      processed_pdf.attach(io: File.open(output_path), filename: "processed-#{id}.pdf", content_type: "application/pdf")

      # Clean up working files
      FileUtils.rm_rf(work_dir) if File.directory?(work_dir)

      # Set the status to 'completed' after successful processing
      update_column(:status, :completed)
      
      Rails.logger.info "Finished apply_all_elements successfully for PDF #{id}"
      true
    rescue => e
      Rails.logger.error "Error in apply_all_elements for PDF #{id}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      # Set status to error when exception occurs
      update_column(:status, :error)
      false
    end
  end
end
