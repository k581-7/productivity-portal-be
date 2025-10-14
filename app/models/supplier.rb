class Supplier < ApplicationRecord
  # Define the ENUMS
  enum priority: { high: 0, medium: 1, low: 2 }
  enum status: { ongoing: 0, queued: 1, cancelled: 2, completed: 3 }

  # Define the association to the User model
  belongs_to :assigned_pic, class_name: 'User', foreign_key: 'assigned_pic_id'

  has_many :prod_entries
end
