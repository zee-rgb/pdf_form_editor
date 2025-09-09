# frozen_string_literal: true

require "rails_helper"

RSpec.describe PdfDocument, type: :model do
  describe "validations" do
    it "is valid with valid attributes" do
      pdf_document = build(:pdf_document)
      expect(pdf_document).to be_valid
    end

    it "requires a title" do
      pdf_document = build(:pdf_document, title: nil)
      expect(pdf_document).not_to be_valid
      expect(pdf_document.errors[:title]).to include("can't be blank")
    end

    it "requires a pdf_file" do
      pdf_document = build(:pdf_document)
      pdf_document.pdf_file = nil
      expect(pdf_document).not_to be_valid
      expect(pdf_document.errors[:pdf_file]).to include("can't be blank")
    end

    it "requires a user" do
      pdf_document = build(:pdf_document, user: nil)
      expect(pdf_document).not_to be_valid
      expect(pdf_document.errors[:user]).to include("must exist")
    end
  end

  describe "associations" do
    it "belongs to user" do
      association = described_class.reflect_on_association(:user)
      expect(association.macro).to eq(:belongs_to)
    end

    it "has one attached pdf_file" do
      pdf_document = create(:pdf_document)
      expect(pdf_document.pdf_file).to be_attached
    end

    it "has one attached processed_pdf" do
      pdf_document = create(:pdf_document, :with_processed_pdf)
      expect(pdf_document.processed_pdf).to be_attached
    end
  end

  describe "enums" do
    it "defines status enum" do
      expect(PdfDocument.statuses).to eq({
        "uploaded" => 0,
        "processing" => 1,
        "completed" => 2,
        "error" => 3
      })
    end

    it "can have uploaded status" do
      pdf_document = create(:pdf_document)
      expect(pdf_document).to be_uploaded
    end

    it "can have completed status" do
      pdf_document = create(:pdf_document, :completed)
      expect(pdf_document).to be_completed
    end

    it "can have processing status" do
      pdf_document = create(:pdf_document, :processing)
      expect(pdf_document).to be_processing
    end

    it "can have error status" do
      pdf_document = create(:pdf_document, :error)
      expect(pdf_document).to be_error
    end
  end

  describe "#add_text_overlay" do
    let(:pdf_document) { create(:pdf_document) }

    it "responds to add_text_overlay method" do
      expect(pdf_document).to respond_to(:add_text_overlay)
    end

    it "accepts x, y, text, and page parameters" do
      expect { pdf_document.add_text_overlay(100, 200, "Test Text", 0) }.not_to raise_error
    end
  end

  describe "#add_signature_overlay" do
    let(:pdf_document) { create(:pdf_document) }

    it "responds to add_signature_overlay method" do
      expect(pdf_document).to respond_to(:add_signature_overlay)
    end

    it "accepts x, y, signature_data, and page parameters" do
      signature_data = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI7wAAAABJRU5ErkJggg=="
      expect { pdf_document.add_signature_overlay(100, 200, signature_data, 0) }.not_to raise_error
    end
  end
end
