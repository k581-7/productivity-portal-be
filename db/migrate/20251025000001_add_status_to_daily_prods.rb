class AddStatusToDailyProds < ActiveRecord::Migration[8.0]
  def change
    add_column :daily_prods, :status, :string
    add_index :daily_prods, :status
  end
end