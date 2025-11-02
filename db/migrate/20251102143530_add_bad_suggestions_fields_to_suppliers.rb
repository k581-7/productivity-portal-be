class AddBadSuggestionsFieldsToSuppliers < ActiveRecord::Migration[8.0]
  def change
    add_column :suppliers, :bs_manually_mapped, :integer
    add_column :suppliers, :bs_incorrect_supplier_data, :integer
    add_column :suppliers, :bs_insufficient_info, :integer
    add_column :suppliers, :bs_created_property, :integer
    add_column :suppliers, :bs_reactivated_total, :integer
    add_column :suppliers, :nc_reactivated_total, :integer
  end
end
