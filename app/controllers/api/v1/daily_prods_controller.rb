module Api
  module V1
    class DailyProdsController < ApplicationController
      before_action :authenticate_user!

      # GET /api/v1/daily_prods?month=October
      def index
        month = params[:month] || Date.today.strftime('%B')
        year = params[:year] || Date.today.year
        
        # Get all prod_entries for the specified month
        start_date = Date.parse("#{year}-#{Date::MONTHNAMES.index(month)}-01")
        end_date = start_date.end_of_month
        
        prod_entries = ProdEntry
          .includes(:assigned_user, :supplier)
          .where(date: start_date..end_date)
          .order(:date)
        
        # Get all users who have either prod_entries OR daily_prod records
        users_with_entries = prod_entries.pluck(:assigned_user_id).uniq
        users_with_daily_prods = DailyProd.where(date: start_date..end_date).pluck(:user_id).uniq
        all_user_ids = (users_with_entries + users_with_daily_prods).uniq
        
        # Load all daily_prods for the month at once to avoid N+1 queries
        all_daily_prods = DailyProd.where(
          user_id: all_user_ids,
          date: start_date..end_date
        ).to_a
        
        # Create a lookup hash: {user_id => {date => daily_prod}}
        daily_prods_lookup = all_daily_prods.group_by(&:user_id).transform_values do |dps|
          dps.index_by(&:date)
        end
        
        # Group by user and date
        daily_data = all_user_ids.map do |user_id|
          user = User.find_by(id: user_id)
          next unless user
          
          user_entries = prod_entries.select { |e| e.assigned_user_id == user_id }
          
          # Get all dates in the range for this user (either from entries or daily_prods)
          dates_with_entries = user_entries.map(&:date).uniq
          dates_with_statuses = daily_prods_lookup.dig(user_id)&.keys || []
          all_dates = (dates_with_entries + dates_with_statuses).uniq.sort
          
          # Calculate totals for each date
          date_entries = all_dates.map do |date|
            day_entries = user_entries.select { |e| e.date == date }
            
            # Look up daily_prod from the hash instead of querying the database
            daily_prod = daily_prods_lookup.dig(user_id, date)
            
            # Calculate manual and auto totals
            manual_total = day_entries.sum do |e|
              (e.manually_mapped || 0) + 
              (e.incorrect_supplier_data || 0) + 
              (e.insufficient_info || 0) + 
              (e.created_property || 0)
            end
            
            auto_total = day_entries.sum do |e|
              (e.accepted || 0) + (e.dismissed || 0)
            end
            
            # Determine mapping type
            mapping_type = if manual_total > 0 && auto_total > 0
              'hybrid'
            elsif auto_total > 0
              'auto'
            elsif manual_total > 0
              'manual'
            end
            
            # IMPORTANT: Check if there's a status set in daily_prod
            # But only use it if there are NO productivity numbers
            has_productivity = manual_total > 0 || auto_total > 0
            
            if daily_prod&.status.present? && !has_productivity
              # If status is set AND no productivity, return status with zero totals
              {
                date: date.strftime('%Y-%m-%d'),
                manual_total: 0,
                auto_total: 0,
                overall_total: 0,
                mapping_type: nil,
                duplicates_total: 0,
                created_property_total: 0,
                status: daily_prod.status
              }
            else
              # Otherwise return calculated totals (productivity overrides status)
              {
                date: date.strftime('%Y-%m-%d'),
                manual_total: manual_total,
                auto_total: auto_total,
                overall_total: manual_total + auto_total,
                mapping_type: mapping_type,
                duplicates_total: day_entries.sum { |e| e.duplicate || 0 },
                created_property_total: day_entries.sum { |e| e.created_property || 0 },
                status: nil
              }
            end
          end
          
          # Calculate accepted and dismissed totals
          accepted_total = user_entries.sum { |e| e.accepted || 0 }
          dismissed_total = user_entries.sum { |e| e.dismissed || 0 }
          
          # Calculate daily average
          work_days = date_entries.count { |e| e[:overall_total] > 0 }
          total_prod = date_entries.sum { |e| e[:overall_total] }
          daily_average = work_days > 0 ? (total_prod.to_f / work_days).round(2) : 0
          
          {
            user_id: user_id,
            user_name: user&.name || 'Unknown',
            accepted: accepted_total,
            dismissed: dismissed_total,
            daily_average: daily_average,
            total: total_prod,
            entries: date_entries
          }
        end.compact
        
        # Filter out any entries with nil user_id
        daily_data = daily_data.select { |data| data[:user_id].present? }
        
        render json: daily_data
      end
      
      # GET /api/v1/daily_prods/summary
      # PATCH /api/v1/daily_prods/update_cell
      def update_cell
        Rails.logger.info "UPDATE CELL - Received params: #{params.inspect}"
        user_id = params[:user_id]
        date_str = params[:date]
        value = params[:value]
        is_status = params[:is_status]

        # Parse date consistently
        parsed_date = if date_str.is_a?(String)
                       Date.parse(date_str)
                     else
                       date_str.to_date
                     end
        
        Rails.logger.info "UPDATE CELL - Parsed date: #{parsed_date}, value: #{value}, is_status: #{is_status}"
        
        daily_prod = DailyProd.find_or_initialize_by(
          user_id: user_id,
          date: parsed_date
        )

        # Set the month
        daily_prod.month = parsed_date.strftime('%B')

        if is_status
          # Handle status update - set status and zero out all totals
          daily_prod.status = value
          daily_prod.auto_total = 0
          daily_prod.manual_total = 0
          daily_prod.overall_total = 0
          daily_prod.duplicates_total = 0
          daily_prod.created_property_total = 0
          daily_prod.daily_average = 0
        else
          # Handle numeric update - clear status
          daily_prod.status = nil
          daily_prod.overall_total = value.to_i
        end

        if daily_prod.save
          Rails.logger.info "Daily prod saved successfully: #{daily_prod.inspect}"
          render json: daily_prod
        else
          Rails.logger.error "Failed to save daily prod: #{daily_prod.errors.full_messages}"
          render json: { 
            error: daily_prod.errors.full_messages.join(", "),
            received_params: params
          }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/daily_prods/delete_status
      def delete_status
        user_id = params[:user_id]
        date_str = params[:date]

        Rails.logger.info "DELETE STATUS - Received params: user_id=#{user_id}, date=#{date_str}"
        
        # Parse date consistently with how it's stored
        parsed_date = if date_str.is_a?(String)
                       Date.parse(date_str)
                     else
                       date_str.to_date
                     end
        
        Rails.logger.info "DELETE STATUS - Parsed date: #{parsed_date}"
        
        daily_prod = DailyProd.find_by(
          user_id: user_id,
          date: parsed_date
        )

        Rails.logger.info "DELETE STATUS - Found daily_prod: #{daily_prod.inspect}"

        if daily_prod
          # Just update the status to nil instead of deleting the record
          if daily_prod.update(status: nil)
            Rails.logger.info "DELETE STATUS - Successfully cleared status"
            render json: { message: 'Status cleared successfully', date: parsed_date }
          else
            Rails.logger.error "DELETE STATUS - Failed to update: #{daily_prod.errors.full_messages}"
            render json: { error: 'Failed to clear status' }, status: :unprocessable_entity
          end
        else
          Rails.logger.warn "DELETE STATUS - No daily_prod found for user #{user_id} on #{parsed_date}"
          render json: { message: 'No status found to clear' }, status: :not_found
        end
      end

      def summary
        # Get date range (default to current month or accept params)
        start_date = params[:start_date] ? Date.parse(params[:start_date]) : Date.today.beginning_of_month
        end_date = params[:end_date] ? Date.parse(params[:end_date]) : Date.today.end_of_month
        
        prod_entries = ProdEntry.where(date: start_date..end_date).order(:date)
        
        # Group by date for trend analysis
        daily_totals = prod_entries.group_by(&:date).map do |date, entries|
          manual_total = entries.sum do |e|
            (e.manually_mapped || 0) + 
            (e.incorrect_supplier_data || 0) + 
            (e.insufficient_info || 0) + 
            (e.created_property || 0)
          end
          
          auto_total = entries.sum { |e| (e.accepted || 0) + (e.dismissed || 0) }
          
          mapping_type = if manual_total > 0 && auto_total > 0
            'hybrid'
          elsif auto_total > 0
            'auto'
          elsif manual_total > 0
            'manual'
          end
          
          {
            date: date.strftime('%b %d'),
            manual_mapping: manual_total,
            auto_mapping: auto_total,
            mapping_type: mapping_type,
            duplicates: entries.sum { |e| e.duplicate || 0 },
            created_property: entries.sum { |e| e.created_property || 0 }
          }
        end
        
        # Calculate overall totals
        manual_total = prod_entries.sum do |e|
          (e.manually_mapped || 0) + 
          (e.incorrect_supplier_data || 0) + 
          (e.insufficient_info || 0) + 
          (e.created_property || 0)
        end
        
        auto_total = prod_entries.sum { |e| (e.accepted || 0) + (e.dismissed || 0) }
        
        totals = {
          manual_mapping: manual_total,
          auto_mapping: auto_total,
          duplicates: prod_entries.sum { |e| e.duplicate || 0 },
          cannot_be_mapped: prod_entries.sum { |e| (e.incorrect_supplier_data || 0) + (e.insufficient_info || 0) },
          created_property: prod_entries.sum { |e| e.created_property || 0 },
          mapping_type: if manual_total > 0 && auto_total > 0
                        'hybrid'
                      elsif auto_total > 0
                        'auto'
                      elsif manual_total > 0
                        'manual'
                      end
        }
        
        render json: {
          labels: daily_totals.map { |d| d[:date] },
          manual_mapping: daily_totals.map { |d| d[:manual_mapping] },
          auto_mapping: daily_totals.map { |d| d[:auto_mapping] },
          mapping_types: daily_totals.map { |d| d[:mapping_type] },
          duplicates: daily_totals.map { |d| d[:duplicates] },
          created_property: daily_totals.map { |d| d[:created_property] },
          totals: totals
        }
      end
    end
  end
end