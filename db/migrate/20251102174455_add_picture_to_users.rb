class AddPictureToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :picture, :string
  end
end
