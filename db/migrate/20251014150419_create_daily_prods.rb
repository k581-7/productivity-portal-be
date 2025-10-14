class CreateDailyProds < ActiveRecord::Migration[8.0]
  def change
    create_table :daily_prods do |t|
      t.references :user, foreign_key: true, index: true, null: false
      t.string :month, index: true
      t.date :date, index: true
      t.integer :manual_total
      t.integer :auto_total
      t.integer :overall_total
      t.integer :duplicates_total
      t.integer :created_property_total
      t.decimal :daily_average, precision: 10, scale: 2

      t.timestamps
    end
  end
end
