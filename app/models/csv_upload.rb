class CsvUpload < ApplicationRecord
  belongs_to :supplier
  belongs_to :uploaded_by, class_name: 'User', foreign_key: 'uploaded_by_id'
  
  validates :batch_id, presence: true, uniqueness: true
  validates :filename, presence: true
  validates :source_type, presence: true
end
