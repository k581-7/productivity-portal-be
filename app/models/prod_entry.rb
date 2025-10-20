class ProdEntry < ApplicationRecord
  belongs_to :entered_by_user, class_name: 'User'
  belongs_to :assigned_user, class_name: 'User', optional: true
  belongs_to :supplier

  validates :entered_by_user, presence: true
  validates :supplier, presence: true
  validates :mapping_type, presence: true
  validates :source, presence: true
  validates :date, presence: true

  enum :mapping_type, { auto: 0, manual: 1, hybrid: 2 }
  enum :source, { api: 0, manual_upload: 1, csv_import: 2 }
end