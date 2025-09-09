class ChangeStatusColumnToPdfDocuments < ActiveRecord::Migration[8.0]
  def up
    change_column :pdf_documents, :status, :integer, default: 0
  end

  def down
    change_column :pdf_documents, :status, :string
  end
end
