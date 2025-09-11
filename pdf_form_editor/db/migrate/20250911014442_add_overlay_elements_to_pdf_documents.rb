class AddOverlayElementsToPdfDocuments < ActiveRecord::Migration[8.0]
  def change
    add_column :pdf_documents, :overlay_elements, :text
  end
end
