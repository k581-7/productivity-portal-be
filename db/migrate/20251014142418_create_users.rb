class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.string :name, null: false
      t.string :email, null: false, index: { unique: true }
      t.string :google_id, index: true
      t.integer :role, null: false, default: 3
      
      t.timestamps
    end
  end
end
