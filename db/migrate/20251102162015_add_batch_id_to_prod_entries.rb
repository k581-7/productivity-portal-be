class AddBatchIdToProdEntries < ActiveRecord::Migration[8.0]
  def change
    add_column :prod_entries, :batch_id, :string
    add_index :prod_entries, :batch_id
  end
end
