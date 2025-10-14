class CreateSummaryDashboards < ActiveRecord::Migration[8.0]
  def change
    create_table :summary_dashboards do |t|
      t.references :user, foreign_key: true, null: false 
      t.date :period_start, null: false
      t.date :period_end
      t.integer :manual_total
      t.integer :auto_total
      t.integer :incorrect_data_total
      t.integer :dismissed_total
      t.integer :duplicate_total
      t.integer :total_productivity

      t.timestamps
    end
  end
end
