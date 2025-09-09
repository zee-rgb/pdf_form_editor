# frozen_string_literal: true

require "rails_helper"

RSpec.describe User, type: :model do
  describe "validations" do
    it "is valid with valid attributes" do
      user = build(:user)
      expect(user).to be_valid
    end

    it "requires an email" do
      user = build(:user, email: nil)
      expect(user).not_to be_valid
      expect(user.errors[:email]).to include("can't be blank")
    end

    it "requires a unique email" do
      create(:user, email: "test@example.com")
      user = build(:user, email: "test@example.com")
      expect(user).not_to be_valid
      expect(user.errors[:email]).to include("has already been taken")
    end

    it "requires a password" do
      user = build(:user, password: nil)
      expect(user).not_to be_valid
      expect(user.errors[:password]).to include("can't be blank")
    end
  end

  describe "associations" do
    it "has many pdf_documents" do
      association = described_class.reflect_on_association(:pdf_documents)
      expect(association.macro).to eq(:has_many)
    end

    it "destroys associated pdf_documents when user is deleted" do
      user = create(:user)
      pdf_document = create(:pdf_document, user: user)

      expect { user.destroy }.to change { PdfDocument.count }.by(-1)
    end
  end
end
