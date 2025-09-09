# frozen_string_literal: true

FactoryBot.define do
  factory :pdf_document do
    association :user
    title { "Sample PDF Document" }
    status { "uploaded" }

    after(:build) do |pdf_document|
      # Attach a simple PDF file for testing
      pdf_document.pdf_file.attach(
        io: StringIO.new("%PDF-1.4\n1 0 obj\n<<\n/Type /Catalog\n/Pages 2 0 R\n>>\nendobj\n2 0 obj\n<<\n/Type /Pages\n/Kids [3 0 R]\n/Count 1\n>>\nendobj\n3 0 obj\n<<\n/Type /Page\n/Parent 2 0 R\n/MediaBox [0 0 612 792]\n>>\nendobj\nxref\n0 4\n0000000000 65535 f \n0000000009 00000 n \n0000000074 00000 n \n0000000120 00000 n \ntrailer\n<<\n/Size 4\n/Root 1 0 R\n>>\nstartxref\n179\n%%EOF"),
        filename: "test.pdf",
        content_type: "application/pdf"
      )
    end

    trait :with_processed_pdf do
      after(:create) do |pdf_document|
        pdf_document.processed_pdf.attach(
          io: StringIO.new("%PDF-1.4\n1 0 obj\n<<\n/Type /Catalog\n/Pages 2 0 R\n>>\nendobj\n2 0 obj\n<<\n/Type /Pages\n/Kids [3 0 R]\n/Count 1\n>>\nendobj\n3 0 obj\n<<\n/Type /Page\n/Parent 2 0 R\n/MediaBox [0 0 612 792]\n>>\nendobj\nxref\n0 4\n0000000000 65535 f \n0000000009 00000 n \n0000000074 00000 n \n0000000120 00000 n \ntrailer\n<<\n/Size 4\n/Root 1 0 R\n>>\nstartxref\n179\n%%EOF"),
          filename: "processed_test.pdf",
          content_type: "application/pdf"
        )
      end
    end

    trait :completed do
      status { "completed" }
    end

    trait :processing do
      status { "processing" }
    end

    trait :error do
      status { "error" }
    end
  end
end
