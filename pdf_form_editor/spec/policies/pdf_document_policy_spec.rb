# frozen_string_literal: true

require "rails_helper"

RSpec.describe PdfDocumentPolicy, type: :policy do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:pdf_document) { create(:pdf_document, user: user) }
  let(:other_pdf_document) { create(:pdf_document, user: other_user) }

  describe "#index?" do
    it "grants access to authenticated users" do
      expect(PdfDocumentPolicy.new(user, PdfDocument).index?).to be true
    end

    it "denies access to unauthenticated users" do
      expect(PdfDocumentPolicy.new(nil, PdfDocument).index?).to be false
    end
  end

  describe "#show?" do
    it "grants access to document owner" do
      expect(PdfDocumentPolicy.new(user, pdf_document).show?).to be true
    end

    it "denies access to non-owners" do
      expect(PdfDocumentPolicy.new(other_user, pdf_document).show?).to be false
    end

    it "denies access to unauthenticated users" do
      expect(PdfDocumentPolicy.new(nil, pdf_document).show?).to be false
    end
  end

  describe "#create?" do
    it "grants access to authenticated users" do
      expect(PdfDocumentPolicy.new(user, PdfDocument).create?).to be true
    end

    it "denies access to unauthenticated users" do
      expect(PdfDocumentPolicy.new(nil, PdfDocument).create?).to be false
    end
  end

  describe "#update?" do
    it "grants access to document owner" do
      expect(PdfDocumentPolicy.new(user, pdf_document).update?).to be true
    end

    it "denies access to non-owners" do
      expect(PdfDocumentPolicy.new(other_user, pdf_document).update?).to be false
    end
  end

  describe "#destroy?" do
    it "grants access to document owner" do
      expect(PdfDocumentPolicy.new(user, pdf_document).destroy?).to be true
    end

    it "denies access to non-owners" do
      expect(PdfDocumentPolicy.new(other_user, pdf_document).destroy?).to be false
    end
  end

  describe "#add_text?" do
    it "grants access to document owner" do
      expect(PdfDocumentPolicy.new(user, pdf_document).add_text?).to be true
    end

    it "denies access to non-owners" do
      expect(PdfDocumentPolicy.new(other_user, pdf_document).add_text?).to be false
    end
  end

  describe "#add_signature?" do
    it "grants access to document owner" do
      expect(PdfDocumentPolicy.new(user, pdf_document).add_signature?).to be true
    end

    it "denies access to non-owners" do
      expect(PdfDocumentPolicy.new(other_user, pdf_document).add_signature?).to be false
    end
  end

  describe "#download?" do
    it "grants access to document owner" do
      expect(PdfDocumentPolicy.new(user, pdf_document).download?).to be true
    end

    it "denies access to non-owners" do
      expect(PdfDocumentPolicy.new(other_user, pdf_document).download?).to be false
    end
  end

  describe "Scope" do
    it "returns only user's documents" do
      user_pdf = create(:pdf_document, user: user)
      other_pdf = create(:pdf_document, user: other_user)

      scope = PdfDocumentPolicy::Scope.new(user, PdfDocument).resolve

      expect(scope).to include(user_pdf)
      expect(scope).not_to include(other_pdf)
    end

    it "returns empty scope for unauthenticated users" do
      create(:pdf_document, user: user)

      scope = PdfDocumentPolicy::Scope.new(nil, PdfDocument).resolve

      expect(scope).to be_empty
    end
  end
end
