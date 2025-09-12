require "base64"
require "tempfile"
require "image_processing/mini_magick"

class SignatureService
  # Service for generating and manipulating signature images

  def initialize(content = nil, options = {})
    @content = content
    @options = options
    @font = options[:font] || "Dancing Script"
    @size = options[:size] || 40
    @color = options[:color] || "000000" # Black
  end

  # Generate a signature image from text content
  def generate_signature_image
    return nil if @content.blank?

    # For now, create a simple text-based SVG signature
    # This avoids ImageMagick dependencies
    font_family = case @font
    when "Dancing Script"
                   "cursive"
    when "Great Vibes"
                   "cursive"
    when "Allura"
                   "cursive"
    else
                   "Arial, sans-serif"
    end

    # Create an SVG with the text
    svg = <<~SVG
      <svg xmlns="http://www.w3.org/2000/svg" width="400" height="150">
        <style>
          @import url('https://fonts.googleapis.com/css2?family=Dancing+Script&family=Great+Vibes&display=swap');
          .signature {
            font-family: #{font_family};
            font-size: #{@size}px;
            fill: ##{@color};
          }
        </style>
        <text x="50%" y="50%" text-anchor="middle" dominant-baseline="middle" class="signature">#{@content}</text>
      </svg>
    SVG

    # Convert SVG to base64
    base64_data = Base64.strict_encode64(svg)
    "data:image/svg+xml;base64,#{base64_data}"
  rescue => e
    Rails.logger.error "Error generating signature image: #{e.message}"
    nil
  end

  # Process a drawn signature from base64 data
  def process_drawn_signature(signature_data)
    return nil if signature_data.blank?

    # Extract the image data
    image_data = Base64.decode64(signature_data.split(",")[1])

    # Create a temporary file
    temp_file = Tempfile.new([ "drawn_signature", ".png" ])
    temp_file.binmode
    temp_file.write(image_data)
    temp_file.close

    # Process the image - resize if needed and optimize
    begin
      processed = ImageProcessing::MiniMagick
        .source(temp_file.path)
        .resize_to_limit(400, 150)
        .background("transparent")
        .format("png")
        .call

      # Return as base64
      processed_data = File.binread(processed.path)
      base64_data = Base64.strict_encode64(processed_data)
      "data:image/png;base64,#{base64_data}"
    rescue => e
      Rails.logger.error "Error processing drawn signature: #{e.message}"
      signature_data # Return original if processing fails
    ensure
      temp_file.unlink
    end
  end

  private

  def get_font_path(font_name)
    # Try custom fonts if they exist, otherwise use system fonts
    case font_name
    when "Dancing Script"
      font_path = Rails.root.join("app", "assets", "fonts", "dancing_script.ttf")
      font_path.exist? ? font_path.to_s : get_system_font("script")
    when "Great Vibes"
      font_path = Rails.root.join("app", "assets", "fonts", "great_vibes.ttf")
      font_path.exist? ? font_path.to_s : get_system_font("script")
    when "Allura"
      font_path = Rails.root.join("app", "assets", "fonts", "allura.ttf")
      font_path.exist? ? font_path.to_s : get_system_font("script")
    else
      # Default system font
      get_system_font("default")
    end
  end

  def get_system_font(type)
    # Return appropriate system fonts based on OS and type
    case type
    when "script"
      if RUBY_PLATFORM =~ /darwin/i
        # macOS script fonts
        [ "/Library/Fonts/Zapfino.ttf", "/Library/Fonts/Snell Roundhand.ttf", "Brush Script MT" ].find do |font|
          File.exist?(font) || font # If file path doesn't exist, just return the name as fallback
        end
      else
        # Other OS - just return name and hope ImageMagick can find it
        "Brush Script MT"
      end
    else
      # Default font
      if RUBY_PLATFORM =~ /darwin/i
        # macOS default fonts
        [ "/Library/Fonts/Helvetica.ttc", "/Library/Fonts/Arial.ttf", "Helvetica" ].find do |font|
          File.exist?(font) || font
        end
      else
        "Helvetica"
      end
    end
  end
end
