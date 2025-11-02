class AddInsufficientInfoToSuppliers < ActiveRecord::Migration[8.0]
  def change
    add_column :suppliers, :insufficient_info, :integer
  end
end
