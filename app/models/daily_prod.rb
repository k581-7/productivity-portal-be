class DailyProd < ApplicationRecord
  belongs_to :user
  
  # Fix the valid statuses (remove duplicate 'Offset')
  VALID_STATUSES = ['Exempted', 'Day Off', 'Offset', 'Leave']
  
  validates :status, inclusion: { in: VALID_STATUSES }, allow_nil: true
  validates :date, presence: true
  validates :user_id, presence: true
  
  before_save :handle_status_totals
  
  private
  
  def handle_status_totals
    if status.present?
      self.auto_total = 0
      self.manual_total = 0
      self.overall_total = 0
      self.duplicates_total = 0
      self.created_property_total = 0
    end
  end
end