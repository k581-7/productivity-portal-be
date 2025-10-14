class ProdEntry < ApplicationRecord
  # Define the ENUMS
  enum mapping_type: { manual: 0, auto: 1 }
  enum source: { leader: 0, junior: 1 }

  # Define the ASSOCIATIONS
  
  # Entered by a user (User model)
  belongs_to :entered_by_user, class_name: 'User' 
  
  # Assigned to a user (User model)
  belongs_to :assigned_user, class_name: 'User', optional: true
  
  # Belongs to a supplier (Supplier model)
  belongs_to :supplier
  
end
