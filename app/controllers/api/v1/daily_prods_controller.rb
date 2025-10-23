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
        
        # Group by user and date
        daily_data = prod_entries.group_by(&:assigned_user_id).map do |user_id, entries|
          user = entries.first.assigned_user
          
          # Calculate totals for each date
          date_entries = entries.group_by(&:date).map do |date, day_entries|
            # Calculate manual total (sum of all manual fields)
            manual_total = day_entries.sum do |e|
              (e.manually_mapped || 0) + 
              (e.incorrect_supplier_data || 0) + 
              (e.insufficient_info || 0) + 
              (e.created_property || 0)
            end
            
            # Calculate auto total (sum of accepted and dismissed)
            auto_total = day_entries.sum do |e|
              (e.accepted || 0) + (e.dismissed || 0)
            end
            
            # Determine mapping type based on totals
            mapping_type = if manual_total > 0 && auto_total > 0
              'hybrid'
            elsif auto_total > 0
              'auto'
            elsif manual_total > 0
              'manual'
            end
            
            {
              date: date,
              manual_total: manual_total,
              auto_total: auto_total,
              overall_total: manual_total + auto_total,
              mapping_type: mapping_type,
              duplicates_total: day_entries.sum { |e| e.duplicate || 0 },
              created_property_total: day_entries.sum { |e| e.created_property || 0 }
            }
          end
          
          # Calculate accepted and dismissed totals
          accepted_total = entries.sum { |e| e.accepted || 0 }
          dismissed_total = entries.sum { |e| e.dismissed || 0 }
          
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
        end
        
        # Filter out any entries with nil user_id
        daily_data = daily_data.select { |data| data[:user_id].present? }
        
        render json: daily_data
      end
      
      # GET /api/v1/daily_prods/summary
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