class CreateCsvUploads < ActiveRecord::Migration[8.0]
  def change
    create_table :csv_uploads do |t|
      t.string :batch_id
      t.string :filename
      t.string :source_type
      t.integer :supplier_id
      t.integer :uploaded_by_id
      t.string :manualsheet_type
      t.datetime :upload_date

      t.timestamps
    end
    add_index :csv_uploads, :batch_id, unique: true
  end
end
