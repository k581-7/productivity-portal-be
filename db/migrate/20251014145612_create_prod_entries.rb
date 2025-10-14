class CreateProdEntries < ActiveRecord::Migration[8.0]
  def change
    create_table :prod_entries do |t|
      t.references :entered_by_user, null: false, foreign_key: { to_table: :users }
      t.references :supplier, null: false, foreign_key: true, index: true
      t.references :assigned_user, foreign_key: { to_table: :users }, index: true
      t.date :date, index: true
      t.integer :mapping_type, null: false 
      t.integer :manually_mapped
      t.integer :incorrect_supplier_data
      t.integer :created_property
      t.integer :insufficient_info
      t.integer :accepted
      t.integer :dismissed
      t.integer :no_result
      t.integer :duplicate
      t.integer :reactivated
      t.integer :source, null: false
      t.text :remarks
      
      t.timestamps
    end
  end
end
