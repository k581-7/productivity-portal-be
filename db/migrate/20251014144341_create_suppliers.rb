class CreateSuppliers < ActiveRecord::Migration[8.0]
  def change
    create_table :suppliers do |t|
      t.string :name, null: false
      t.date :request_date
      t.date :start_date, index: true
      t.date :completed_date, index: true
      t.integer :priority, null: false, default: 1
      t.string :requester
      t.integer :status, index: true, default: 1
      t.integer :total_requests
      t.integer :total_mapped
      t.integer :total_pending
      t.integer :automapping_covered_total
      t.integer :suggestions_total
      t.integer :accepted_total
      t.integer :dismissed_total
      t.integer :manual_total
      t.integer :manually_mapped
      t.integer :incorrect_supplier_data
      t.integer :duplicate_count
      t.integer :created_property
      t.integer :not_covered
      t.integer :nc_manually_mapped
      t.integer :nc_created_property
      t.integer :nc_incorrect_supplier
      t.integer :jp_props
      t.integer :reactivated_total
      t.text :remarks

      t.timestamps
      t.references :assigned_pic, foreign_key: { to_table: :users }, index: true, null: false
    end
  end
end
