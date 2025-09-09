namespace :sample do
  desc "Generate a sample PDF for testing"
  task pdf: :environment do
    require "hexapdf"

    # Create sample PDF
    doc = HexaPDF::Document.new
    page = doc.pages.add([ 0, 0, 612, 792 ]) # Letter size
    canvas = page.canvas
    canvas.font("Helvetica", size: 24)

    # Add header
    canvas.text("Sample Form Document", at: [ 50, 750 ])

    canvas.font("Helvetica", size: 12)

    # Add form-like content
    canvas.text("Personal Information:", at: [ 50, 700 ])
    canvas.text("Name: _________________________", at: [ 70, 670 ])
    canvas.text("Email: _________________________", at: [ 70, 640 ])
    canvas.text("Phone: _________________________", at: [ 70, 610 ])

    canvas.text("Address:", at: [ 50, 570 ])
    canvas.text("Street: _________________________", at: [ 70, 540 ])
    canvas.text("City: _________________________", at: [ 70, 510 ])
    canvas.text("State: _________  ZIP: _________", at: [ 70, 480 ])

    canvas.text("Agreement:", at: [ 50, 430 ])
    canvas.text("I agree to the terms and conditions.", at: [ 70, 400 ])
    canvas.text("Signature: _________________________  Date: _________", at: [ 70, 350 ])

    # Add some guidelines
    canvas.font("Helvetica", size: 11, variant: :italic)
    canvas.text("Instructions: Click anywhere on this PDF to add text or signatures.", at: [ 50, 280 ])

    canvas.font("Helvetica", size: 10)
    canvas.text("• Type text in the sidebar and click to place it", at: [ 70, 250 ])
    canvas.text("• Use the signature tools to draw, upload, or type signatures", at: [ 70, 220 ])
    canvas.text("• Download the completed PDF when done", at: [ 70, 190 ])

    # Save to public directory
    sample_path = Rails.root.join("public", "sample_form.pdf").to_s
    doc.write(sample_path)

    puts "Sample PDF created at: #{sample_path}"
    puts "You can download it at: http://localhost:3001/sample_form.pdf"
  end
end
