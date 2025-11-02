require 'csv'
module Api
  module V1
    class ProdEntriesController < ApplicationController
      before_action :authenticate_user!
      before_action :check_guest_access! # Guest cannot access Prod Entries at all
      before_action :authorize_developer_or_leader!, only: [:create, :upload_history, :delete_upload]

      # GET /api/v1/prod_entries/upload_history
      # Only Leader and Developer can see upload history
      def upload_history

        uploads = CsvUpload
          .includes(:supplier, :uploaded_by)
          .order(upload_date: :desc)
          .map do |upload|
            # Count entries for this batch
            entry_count = ProdEntry.where(batch_id: upload.batch_id).count
            
            {
              id: upload.id,
              batch_id: upload.batch_id,
              filename: upload.filename,
              source_type: upload.source_type,
              manualsheet_type: upload.manualsheet_type,
              supplier: {
                id: upload.supplier&.id,
                name: upload.supplier&.name
              },
              uploaded_by: {
                id: upload.uploaded_by&.id,
                name: upload.uploaded_by&.name
              },
              upload_date: upload.upload_date,
              entry_count: entry_count
            }
          end

        render json: uploads
      end

      # GET /api/v1/prod_entries
      # Junior, Leader, and Developer can view
      def index
        # Leaders and developers can see all entries
        if current_user.leader? || current_user.developer?
          @prod_entries = ProdEntry
            .includes(:supplier, :assigned_user, :entered_by_user)
            .all
        else
          @prod_entries = ProdEntry
            .includes(:supplier, :assigned_user, :entered_by_user)
            .where(assigned_user_id: current_user.id)
        end
        
        render json: @prod_entries, include: [:supplier, :assigned_user, :entered_by_user]
      end
      
      # POST /api/v1/prod_entries
      # Only Leader and Developer can create entries (CSV upload)
      def create
  Rails.logger.info "PARAMS: #{params.inspect}"

        # Support multiple file uploads
        supplier_id = params[:supplier_id]
        files = params[:csv_files] || [params[:csv_file]].compact
        sources = params[:sources] || [params[:source]].compact
        manualsheet_type = params[:manualsheet_type] # 'bad_suggestions' or other types

        unless supplier_id && files.any? && sources.any?
          render json: { error: 'Missing required parameters' }, status: :unprocessable_entity
          return
        end
        
        # Use supplier's start_date if no date is provided
        supplier = Supplier.find_by(id: supplier_id)
        unless supplier
          render json: { error: 'Supplier not found' }, status: :not_found
          return
        end
        date = params[:date] || supplier.start_date || Date.today
        
        Rails.logger.info "Processing CSV - supplier_id: #{supplier_id}, source: #{sources}, manualsheet_type: #{manualsheet_type}"

        require 'csv'
        
        # Generate unique batch_id for this upload session
        batch_id = SecureRandom.uuid
        
        files.each_with_index do |csv_file, idx|
          source_type = (sources[idx] || sources.first).to_s.downcase
          # Read file as binary, force encode to UTF-8, replace invalid/undefined chars
          raw = File.read(csv_file.path, mode: 'rb')
          utf8 = raw.encode('UTF-8', invalid: :replace, undef: :replace, replace: '')

          # Parse headers
          csv_headers = CSV.parse(utf8, headers: true).first.headers
          valid_headers = case source_type
          when 'autosheet'
            ["Supplier Code", "Score", "Status", "PIC", "Date", "Duplicate", "Remarks"]
          when 'manualsheet'
            ["Supplier Code", "RTX Code", "Property Name", "Address", "City", "Country Code", "To Map", "Mapping Status", "Remarks", "PIC", "Date"]
          when 'logs'
            ["Timestamp", "Event", "User", "Supplier code"]
          else
            nil
          end

          required_headers = valid_headers
          actual_headers = csv_headers.map { |h| h.to_s.strip }
          if required_headers.nil?
            render json: { error: "Unknown or missing source type: #{source_type}" }, status: :unprocessable_entity
            return
          end
          unless (required_headers - actual_headers).empty?
            render json: { error: "CSV headers do not match expected format for #{source_type}" }, status: :unprocessable_entity
            return
          end

          # Parse and aggregate data for DailyProd and Supplier
          CSV.parse(utf8, headers: true).each do |row|
            case source_type
            when 'autosheet'
              status = row['Status']
              pic = row['PIC']
              date_str = row['Date']
              duplicate_value = row['Duplicate'].to_s.strip
              
              # Parse date properly - handle formats like "30-Oct-25"
              entry_date = begin
                parsed = Date.parse(date_str.to_s)
                # Fix 2-digit year parsing (25 -> 2025 instead of 0025)
                if parsed.year < 100
                  Date.new(2000 + parsed.year, parsed.month, parsed.day)
                else
                  parsed
                end
              rescue
                date # fallback to provided date param
              end
              
              # Find user with case-insensitive search
              user = User.where('LOWER(name) = ?', pic.to_s.strip.downcase).first
              Rails.logger.info "Autosheet - Matched user: #{pic} => #{user&.id}, Date: #{date_str} -> #{entry_date}, Status: #{status}"
              next unless user
              
              # Count duplicates as 1 if there's any non-empty value
              has_duplicate = !duplicate_value.empty? && duplicate_value != '0'
              
              daily_prod = DailyProd.find_or_initialize_by(user_id: user.id, date: entry_date)
              daily_prod.auto_total = (daily_prod.auto_total || 0) + 1
              if has_duplicate
                daily_prod.duplicates_total = (daily_prod.duplicates_total || 0) + 1
              end
              daily_prod.save
              
              supplier = Supplier.find_by(id: supplier_id)
              supplier.update(assigned_pic_id: user.id) if supplier && user
              
              # Determine accepted/dismissed based on status
              accepted = (status.to_s.downcase == 'accepted') ? 1 : 0
              dismissed = (status.to_s.downcase == 'dismissed') ? 1 : 0
              
              # Update Supplier Automapping totals
              if supplier
                supplier.update(
                  accepted_total: (supplier.accepted_total || 0) + accepted,
                  dismissed_total: (supplier.dismissed_total || 0) + dismissed,
                  duplicate_count: (supplier.duplicate_count || 0) + (has_duplicate ? 1 : 0)
                )
                Rails.logger.info "AUTOSHEET - Supplier updated: accepted_total: #{supplier.accepted_total}, dismissed_total: #{supplier.dismissed_total}, duplicate_count: #{supplier.duplicate_count}"
              end
              
              # Save prod entry for autosheet
              ProdEntry.create!(
                supplier_id: supplier_id,
                date: entry_date,
                source: :csv_import,
                mapping_type: :auto,
                assigned_user_id: user.id,
                entered_by_user_id: current_user.id,
                batch_id: batch_id,
                duplicate: has_duplicate ? 1 : 0,
                accepted: accepted,
                dismissed: dismissed
              )
            when 'manualsheet'
              to_map = row['To Map']
              mapping_status = row['Mapping Status']
              pic = row['PIC']
              date_str = row['Date']
              
              # Parse date properly - handle formats like "30-Oct-25"
              entry_date = begin
                parsed = Date.parse(date_str.to_s)
                # Fix 2-digit year parsing (25 -> 2025 instead of 0025)
                if parsed.year < 100
                  Date.new(2000 + parsed.year, parsed.month, parsed.day)
                else
                  parsed
                end
              rescue
                date # fallback to provided date param
              end
              
              user = User.where('LOWER(name) = ?', pic.to_s.strip.downcase).first
              Rails.logger.info "Manualsheet - Matched user: #{pic} => #{user&.id}, Date: #{date_str} -> #{entry_date}"
              next unless user
              
              # Normalize the "To Map" value for comparison (trim and case-insensitive)
              to_map_normalized = to_map.to_s.strip.downcase
              
              # Count as manual mapping if "To Map" column indicates work was done
              # Values like "cannot be mapped", "ok", or any non-empty mapping status
              should_count = to_map_normalized == 'cannot be mapped' || 
                            to_map_normalized == 'ok' || 
                            (!to_map_normalized.empty? && mapping_status.to_s.strip != '')
              
              Rails.logger.info "Manualsheet - To Map: '#{to_map}', Normalized: '#{to_map_normalized}', Mapping Status: '#{mapping_status}', Should count: #{should_count}"
              
              if should_count
                # Determine the type: Bad Suggestions, Not Covered, or Manual Mapping (Common)
                is_bad_suggestions = (manualsheet_type == 'bad_suggestions')
                is_not_covered = (manualsheet_type == 'not_covered')
                is_manual_mapping = (manualsheet_type == 'common' || manualsheet_type.nil? || manualsheet_type.blank?)
                
                # Update daily_prod for ALL manualsheet types (Common, Bad Suggestions, Not Covered)
                # This ensures that any manual work contributes to Daily Prod totals
                # and triggers hybrid mode when combined with Autosheet
                daily_prod = DailyProd.find_or_initialize_by(user_id: user.id, date: entry_date)
                daily_prod.manual_total = (daily_prod.manual_total || 0) + 1
                
                # Normalize mapping status for comparison
                mapping_status_normalized = mapping_status.to_s.strip.downcase
                
                # Track created properties separately
                if mapping_status_normalized.include?('created property')
                  daily_prod.created_property_total = (daily_prod.created_property_total || 0) + 1
                end
                
                daily_prod.save
                
                supplier = Supplier.find_by(id: supplier_id)
                supplier.update(assigned_pic_id: user.id) if supplier && user
                
                # Normalize mapping status for comparison
                mapping_status_normalized = mapping_status.to_s.strip.downcase
                
                # Determine field values based on Mapping Status
                manually_mapped = (mapping_status_normalized.include?('manually mapped') || mapping_status_normalized.include?('already mapped')) ? 1 : 0
                incorrect_supplier_data = mapping_status_normalized.include?('incorrect supplier data') ? 1 : 0
                insufficient_info = mapping_status_normalized.include?('insufficient') ? 1 : 0
                created_property = mapping_status_normalized.include?('created property') ? 1 : 0
                jp_property = mapping_status_normalized.include?('jp property') ? 1 : 0
                
                # Check if Remarks contains "reactivated" (case-insensitive)
                remarks = row['Remarks'].to_s.strip
                reactivated = remarks.downcase.include?('reactivated') ? 1 : 0
                
                Rails.logger.info "Manualsheet - Type: #{manualsheet_type}, Status: '#{mapping_status}', manually_mapped: #{manually_mapped}, incorrect: #{incorrect_supplier_data}, insufficient: #{insufficient_info}, created: #{created_property}, jp_property: #{jp_property}, reactivated: #{reactivated}"
                
                # Save prod entry for manualsheet
                prod_entry = ProdEntry.create!(
                  supplier_id: supplier_id,
                  date: entry_date,
                  source: :csv_import,
                  mapping_type: :manual,
                  assigned_user_id: user.id,
                  entered_by_user_id: current_user.id,
                  batch_id: batch_id,
                  manually_mapped: manually_mapped,
                  incorrect_supplier_data: incorrect_supplier_data,
                  insufficient_info: insufficient_info,
                  created_property: created_property,
                  reactivated: reactivated,
                  remarks: remarks
                )
                
                # Update Supplier totals based on type
                if supplier
                  if is_bad_suggestions
                    # BAD SUGGESTIONS - Update bs_ fields for Bad Suggestions tracking
                    supplier.update(
                      bs_manually_mapped: (supplier.bs_manually_mapped || 0) + manually_mapped,
                      bs_incorrect_supplier_data: (supplier.bs_incorrect_supplier_data || 0) + incorrect_supplier_data,
                      bs_insufficient_info: (supplier.bs_insufficient_info || 0) + insufficient_info,
                      bs_created_property: (supplier.bs_created_property || 0) + created_property,
                      bs_reactivated_total: (supplier.bs_reactivated_total || 0) + reactivated,
                      jp_props: (supplier.jp_props || 0) + jp_property  # JP Property goes to "Others"
                    )
                    Rails.logger.info "BAD SUGGESTIONS - bs_manually_mapped: #{supplier.bs_manually_mapped}, bs_incorrect_supplier_data: #{supplier.bs_incorrect_supplier_data}, bs_insufficient_info: #{supplier.bs_insufficient_info}, bs_created_property: #{supplier.bs_created_property}, bs_reactivated_total: #{supplier.bs_reactivated_total}, jp_props: #{supplier.jp_props}"
                  elsif is_not_covered
                    # NOT COVERED - Update nc_ fields for Not Covered tracking
                    supplier.update(
                      nc_manually_mapped: (supplier.nc_manually_mapped || 0) + manually_mapped,
                      nc_incorrect_supplier: (supplier.nc_incorrect_supplier || 0) + incorrect_supplier_data + insufficient_info,
                      nc_created_property: (supplier.nc_created_property || 0) + created_property,
                      nc_reactivated_total: (supplier.nc_reactivated_total || 0) + reactivated,
                      jp_props: (supplier.jp_props || 0) + jp_property  # JP Property goes to "Others"
                    )
                    Rails.logger.info "NOT COVERED - nc_manually_mapped: #{supplier.nc_manually_mapped}, nc_incorrect_supplier: #{supplier.nc_incorrect_supplier}, nc_created_property: #{supplier.nc_created_property}, nc_reactivated_total: #{supplier.nc_reactivated_total}, jp_props: #{supplier.jp_props}"
                  elsif is_manual_mapping
                    # MANUAL MAPPING (COMMON) - Update regular manual mapping fields
                    supplier.update(
                      manual_total: (supplier.manual_total || 0) + 1,
                      manually_mapped: (supplier.manually_mapped || 0) + manually_mapped,
                      incorrect_supplier_data: (supplier.incorrect_supplier_data || 0) + incorrect_supplier_data,
                      insufficient_info: (supplier.insufficient_info || 0) + insufficient_info,
                      created_property: (supplier.created_property || 0) + created_property,
                      reactivated_total: (supplier.reactivated_total || 0) + reactivated,
                      jp_props: (supplier.jp_props || 0) + jp_property  # JP Property goes to "Others"
                    )
                    Rails.logger.info "MANUAL MAPPING (COMMON) - manual_total: #{supplier.manual_total}, manually_mapped: #{supplier.manually_mapped}, incorrect_supplier_data: #{supplier.incorrect_supplier_data}, insufficient_info: #{supplier.insufficient_info}, created_property: #{supplier.created_property}, reactivated_total: #{supplier.reactivated_total}, jp_props: #{supplier.jp_props}"
                  end
                end
              end
            when 'logs'
              event = row['Event']
              user_name = row['User']
              supplier_code = row['Supplier code']
              timestamp = row['Timestamp']
              
              # Only process SUGGESTION_ACCEPTED and SUGGESTION_REJECTED events
              next unless event == 'SUGGESTION_ACCEPTED' || event == 'SUGGESTION_REJECTED'
              
              # Parse date from timestamp - handle various formats
              entry_date = begin
                parsed = DateTime.parse(timestamp.to_s).to_date
                # Fix 2-digit year parsing (25 -> 2025 instead of 0025)
                if parsed.year < 100
                  Date.new(2000 + parsed.year, parsed.month, parsed.day)
                else
                  parsed
                end
              rescue
                date # fallback to provided date param
              end
              
              # Find user with case-insensitive search
              user = User.where('LOWER(name) = ?', user_name.to_s.strip.downcase).first
              Rails.logger.info "Logs - Matched user: #{user_name} => #{user&.id}, Date: #{timestamp} -> #{entry_date}, Event: #{event}"
              next unless user
              
              # Update daily_prod - both ACCEPTED and REJECTED count as auto_total
              # since Logs represent auto-mapping system events
              daily_prod = DailyProd.find_or_initialize_by(user_id: user.id, date: entry_date)
              mapping_type = :auto
              accepted = 0
              dismissed = 0
              
              if event == 'SUGGESTION_ACCEPTED'
                daily_prod.auto_total = (daily_prod.auto_total || 0) + 1
                accepted = 1
              elsif event == 'SUGGESTION_REJECTED'
                daily_prod.auto_total = (daily_prod.auto_total || 0) + 1
                dismissed = 1
              end
              
              daily_prod.save
              
              supplier = Supplier.find_by(id: supplier_id)
              supplier.update(assigned_pic_id: user.id) if supplier && user
              
              # Save prod entry for logs - all as auto mapping type
              ProdEntry.create!(
                supplier_id: supplier_id,
                date: entry_date,
                source: :csv_import,
                mapping_type: mapping_type,
                assigned_user_id: user.id,
                entered_by_user_id: current_user.id,
                batch_id: batch_id,
                accepted: accepted,
                dismissed: dismissed
              )
            end
          end
        end

        # Create CsvUpload record for tracking
        csv_upload = CsvUpload.create!(
          batch_id: batch_id,
          filename: files.map(&:original_filename).join(', '),
          source_type: sources.first.to_s,
          supplier_id: supplier_id,
          uploaded_by_id: current_user.id,
          manualsheet_type: manualsheet_type,
          upload_date: Time.current
        )

        render json: { 
          message: 'Files processed and data stored successfully.',
          batch_id: batch_id,
          upload_id: csv_upload.id
        }, status: :created
      end

      # DELETE /api/v1/prod_entries/delete_upload/:batch_id
      # Only Leader and Developer can delete uploads
      def delete_upload

        batch_id = params[:batch_id]
        
        unless batch_id
          render json: { error: 'batch_id is required' }, status: :unprocessable_entity
          return
        end

        # Find the CSV upload record
        csv_upload = CsvUpload.find_by(batch_id: batch_id)
        unless csv_upload
          render json: { error: 'Upload not found' }, status: :not_found
          return
        end

        # Find all prod_entries with this batch_id
        prod_entries = ProdEntry.where(batch_id: batch_id)
        
        if prod_entries.empty?
          render json: { error: 'No entries found for this batch_id' }, status: :not_found
          return
        end

        Rails.logger.info "DELETE UPLOAD - batch_id: #{batch_id}, found #{prod_entries.count} entries"

        # Get affected users and dates for recalculation
        affected_records = prod_entries.group_by { |e| [e.assigned_user_id, e.date] }
        
        # Delete all prod_entries with this batch_id
        deleted_count = prod_entries.destroy_all.count
        
        Rails.logger.info "DELETE UPLOAD - Deleted #{deleted_count} prod entries"

        # Recalculate DailyProd totals for affected user-date combinations
        affected_records.each do |(user_id, date), entries|
          daily_prod = DailyProd.find_by(user_id: user_id, date: date)
          next unless daily_prod

          # Get remaining entries for this user-date
          remaining_entries = ProdEntry.where(assigned_user_id: user_id, date: date)
          
          # Recalculate auto_total
          auto_count = remaining_entries.count { |e| e.mapping_type == 'auto' }
          
          # Recalculate manual_total
          manual_count = remaining_entries.sum do |e|
            (e.manually_mapped || 0) + 
            (e.incorrect_supplier_data || 0) + 
            (e.insufficient_info || 0) + 
            (e.created_property || 0)
          end
          
          # Recalculate duplicates
          duplicates_count = remaining_entries.sum { |e| e.duplicate || 0 }
          
          # Recalculate created_property
          created_property_count = remaining_entries.sum { |e| e.created_property || 0 }
          
          if remaining_entries.empty?
            # If no entries left, delete the DailyProd record
            daily_prod.destroy
            Rails.logger.info "DELETE UPLOAD - Deleted DailyProd for user #{user_id}, date #{date}"
          else
            # Update with recalculated totals
            daily_prod.update(
              auto_total: auto_count,
              manual_total: manual_count,
              duplicates_total: duplicates_count,
              created_property_total: created_property_count
            )
            Rails.logger.info "DELETE UPLOAD - Updated DailyProd for user #{user_id}, date #{date}: auto=#{auto_count}, manual=#{manual_count}"
          end
        end

        # Recalculate Supplier totals
        supplier = csv_upload.supplier
        if supplier
          # Get all remaining prod_entries for this supplier
          remaining_supplier_entries = ProdEntry.where(supplier_id: supplier.id)
          
          # Recalculate all supplier fields based on remaining entries
          supplier.update(
            manually_mapped: remaining_supplier_entries.sum { |e| e.manually_mapped || 0 },
            incorrect_supplier_data: remaining_supplier_entries.sum { |e| e.incorrect_supplier_data || 0 },
            insufficient_info: remaining_supplier_entries.sum { |e| e.insufficient_info || 0 },
            created_property: remaining_supplier_entries.sum { |e| e.created_property || 0 },
            duplicate_count: remaining_supplier_entries.sum { |e| e.duplicate || 0 },
            accepted_total: remaining_supplier_entries.sum { |e| e.accepted || 0 },
            dismissed_total: remaining_supplier_entries.sum { |e| e.dismissed || 0 },
            reactivated_total: remaining_supplier_entries.sum { |e| e.reactivated || 0 }
          )
          Rails.logger.info "DELETE UPLOAD - Recalculated Supplier totals for supplier #{supplier.id}"
        end

        # Delete the CSV upload record
        csv_upload.destroy

        render json: { 
          message: 'Upload deleted successfully',
          deleted_entries: deleted_count,
          affected_dates: affected_records.keys.map { |(user_id, date)| { user_id: user_id, date: date } }
        }
      end

      private

      def prod_entry_params
        # Only used for strong params if needed, but now handled directly in create
      end

      def can_assign_to_user?(assigned_user)
        return false unless assigned_user

        # Current user can assign to themselves
        return true if assigned_user.id == current_user.id

        # Leaders and developers can assign to junior users
        if current_user.leader? || current_user.developer?
          return assigned_user.junior?
        end

        false
      end

      def update_supplier_totals(entry)
        supplier = entry.supplier
        return unless supplier

        # This ensures supplier data accumulates correctly
        supplier.update(
          manually_mapped: (supplier.manually_mapped || 0) + (entry.manually_mapped || 0),
          incorrect_supplier_data: (supplier.incorrect_supplier_data || 0) + (entry.incorrect_supplier_data || 0),
          duplicate_count: (supplier.duplicate_count || 0) + (entry.duplicate || 0),
          created_property: (supplier.created_property || 0) + (entry.created_property || 0),
          reactivated_total: (supplier.reactivated_total || 0) + (entry.reactivated || 0),
          accepted_total: (supplier.accepted_total || 0) + (entry.accepted || 0),
          dismissed_total: (supplier.dismissed_total || 0) + (entry.dismissed || 0)
        )
      end

      # Guest role should NOT have access to Prod Entries
      def check_guest_access!
        if current_user&.guest?
          render json: { error: 'Access denied. Guest role does not have access to Productivity Entry.' }, status: :forbidden
        end
      end
    end
  end
end