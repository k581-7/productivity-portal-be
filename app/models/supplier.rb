class Supplier < ApplicationRecord
  belongs_to :assigned_pic, class_name: "User", foreign_key: "assigned_pic_id"
  has_many :prod_entries

  # Explicit Rails 7+ enum syntax
  enum :priority, { low: 0, medium: 1, high: 2 }
  enum :status, { queued: 0, ongoing: 1, cancelled: 2, completed: 3 }

  validates :name, uniqueness: { scope: :start_date, message: "this start date already exists" }
end