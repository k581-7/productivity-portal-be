# developer = User.find_or_create_by(email: "karla.patricia@trx.com") do |user|
#   user.name = "Karla Patricia"
#   user.email = "karla.patricia@trx.com" 
#   user.google_id = "karla24"
#   user.role = "developer"
# end

# leader = User.find_or_create_by(email: "leader.one@trx.com") do |user|
#   user.name = "Leader One"
#   user.google_id = "leader01"
#   user.role = "leader"
# end

# junior = User.find_or_create_by(email: "junior.one@trx.com") do |user|
#   user.name = "Junior One"
#   user.google_id = "junior01"
#   user.role = "junior"
# end

# guest = User.find_or_create_by(email: "guest.one@trx.com") do |user|
#   user.name = "Guest One"
#   user.google_id = "guest01"
#   user.role = "guest"
# end

# puts "Users created or found: #{User.count}"

# Supplier.find_or_create_by!(
#   name: "Supplier1",
#   start_date: Date.today,
#   assigned_pic: leader # ✅ Pass the User object, not a string
# ) do |s|
#   s.request_date = Date.new(2025,10,12)
#   s.priority = "high"
#   s.status = "ongoing"
#   s.requester = "Requester1"
#   s.total_requests = 16200
#   s.total_mapped = 5000
#   s.total_pending = 11200
#   s.automapping_covered_total = 2500
#   s.suggestions_total = 2500
#   s.accepted_total = 1300
#   s.dismissed_total = 1200
#   s.manual_total = 1200
#   s.manually_mapped = 320
#   s.incorrect_supplier_data = 150
#   s.duplicate_count = 38
#   s.created_property = 232
#   s.not_covered = 11200
#   s.nc_manually_mapped = 120
#   s.nc_created_property = 98
#   s.nc_incorrect_supplier = 54
#   s.jp_props = 5
#   s.reactivated_total = 123
#   s.remarks = "For manual mapping."
# end

# puts "Supplier created or found: #{Supplier.count}"
