class DailyProd < ApplicationRecord
  belongs_to :user
  
  # Valid statuses
  VALID_STATUSES = ['Exempted', 'Day Off', 'Offset+Leave', 'Offset + Entry']
  
  # Validations
  validates :status, inclusion: { in: VALID_STATUSES }, allow_nil: true
  validates :date, presence: true
  validates :user_id, presence: true
  
  # Make sure totals are zero when status is set
  before_save :handle_status_totals
  
  private
  
  def handle_status_totals
    if VALID_STATUSES.include?(status)
      self.auto_total = 0
      self.manual_total = 0
      self.overall_total = 0
    end
  end
end

