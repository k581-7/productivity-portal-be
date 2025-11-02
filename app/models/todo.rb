class Todo < ApplicationRecord
  belongs_to :user
  
  validates :content, presence: true
  
  scope :completed, -> { where(completed: true) }
  scope :incomplete, -> { where(completed: false) }
  scope :ordered, -> { order(created_at: :desc) }
end
