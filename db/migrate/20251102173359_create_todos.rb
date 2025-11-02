class CreateTodos < ActiveRecord::Migration[8.0]
  def change
    create_table :todos do |t|
      t.references :user, null: false, foreign_key: true
      t.text :content, null: false
      t.boolean :completed, default: false, null: false

      t.timestamps
    end
    
    add_index :todos, [:user_id, :created_at]
  end
end
