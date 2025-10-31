require 'csv'
module Api
  module V1
    class ProdEntriesController < ApplicationController
      before_action :authenticate_user!

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
      
      def create
  Rails.logger.info "PARAMS: #{params.inspect}"
        # Only leaders and developers can create entries
        unless current_user.leader? || current_user.developer?
          render json: { error: 'Unauthorized' }, status: :forbidden
          return
        end

        # Support multiple file uploads
        supplier_id = params[:supplier_id]
        date = params[:date]
        files = params[:csv_files] || [params[:csv_file]].compact
        sources = params[:sources] || [params[:source]].compact

        unless supplier_id && date && files.any? && sources.any?
          render json: { error: 'Missing required parameters' }, status: :unprocessable_entity
          return
        end

        require 'csv'
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
              # ...existing code for autosheet...
              status = row['Status']
              pic = row['PIC']
              entry_date = row['Date']
              duplicate = row['Duplicate'].to_i rescue 0
              user = User.find_by(name: pic)
              next unless user
              daily_prod = DailyProd.find_or_initialize_by(user_id: user.id, date: entry_date)
              daily_prod.auto_total = (daily_prod.auto_total || 0) + 1
              daily_prod.duplicates_total = (daily_prod.duplicates_total || 0) + duplicate
              daily_prod.save
              supplier = Supplier.find_by(id: supplier_id)
              supplier.update(assigned_pic_id: user.id) if supplier && user
              # Save prod entry for autosheet
              ProdEntry.create!(
                supplier_id: supplier_id,
                date: entry_date,
                source: :csv_import,
                mapping_type: :auto,
                assigned_user_id: user.id,
                entered_by_user_id: current_user.id
              )
            when 'manualsheet'
              # ...existing code for manualsheet...
              to_map = row['To Map']
              mapping_status = row['Mapping Status']
              pic = row['PIC']
              entry_date = row['Date']
              user = User.find_by(name: pic)
              next unless user
              daily_prod = DailyProd.find_or_initialize_by(user_id: user.id, date: entry_date)
              daily_prod.manual_total = (daily_prod.manual_total || 0) + 1
              daily_prod.save
              supplier = Supplier.find_by(id: supplier_id)
              supplier.update(assigned_pic_id: user.id) if supplier && user
              # Save prod entry for manualsheet
              ProdEntry.create!(
                supplier_id: supplier_id,
                date: entry_date,
                source: :csv_import,
                mapping_type: :manual,
                assigned_user_id: user.id,
                entered_by_user_id: current_user.id
              )
            when 'logs'
              # Debug: log row and user matching
              Rails.logger.info "CSV row: #{row.to_h}"
              event = row['Event']
              user_name = row['User']
              supplier_code = row['Supplier code']
              timestamp = row['Timestamp']
              entry_date = begin
                Date.parse(timestamp.to_s)
              rescue
                date # fallback to provided date param
              end
              user = User.where('LOWER(name) = ?', user_name.to_s.strip.downcase).first
              Rails.logger.info "Matched user: #{user_name} => #{user&.id}"
              next unless user
              daily_prod = DailyProd.find_or_initialize_by(user_id: user.id, date: entry_date)
              mapping_type = nil
              if event == 'SUGGESTION_ACCEPTED'
                daily_prod.auto_total = (daily_prod.auto_total || 0) + 1
                mapping_type = :auto
              elsif event == 'SUGGESTION_REJECTED'
                daily_prod.manual_total = (daily_prod.manual_total || 0) + 1
                mapping_type = :manual
              end
              daily_prod.save
              supplier = Supplier.find_by(id: supplier_id)
              supplier.update(assigned_pic_id: user.id) if supplier && user
              if event == 'SUGGESTION_ACCEPTED' || event == 'SUGGESTION_REJECTED'
                ProdEntry.create!(
                  supplier_id: supplier_id,
                  date: entry_date,
                  source: :csv_import,
                  mapping_type: mapping_type,
                  assigned_user_id: user.id,
                  entered_by_user_id: current_user.id
                )
              end
            end
          end
        end

        render json: { message: 'Files processed and data stored successfully.' }, status: :created
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
    end
  end
end