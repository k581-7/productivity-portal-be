module Api
  module V1
    class SummaryController < ApplicationController
      before_action :authenticate_user!
      
      def current_user
        super || begin
          # Add debug logging
          Rails.logger.debug "Authorization Header: #{request.headers['Authorization']}"
          Rails.logger.debug "Current User: #{super.inspect}"
          super
        end
      end

      # GET /api/v1/summary/dashboard
      def dashboard
        begin
          # Get date range (default to current month)
          start_date = params[:start_date] ? Date.parse(params[:start_date]) : Date.today.beginning_of_month
          end_date = params[:end_date] ? Date.parse(params[:end_date]) : Date.today.end_of_month

          Rails.logger.info "Fetching summary data for date range: #{start_date} to #{end_date}"

        # Get all users data if leader/developer, otherwise only current user
        users = if current_user.leader? || current_user.developer?
                 User.all
               else
                 [current_user]
               end

        # Calculate overall metrics
        overall_metrics = calculate_overall_metrics(start_date, end_date)
        user_metrics = calculate_user_metrics(users, start_date, end_date)
        supplier_metrics = calculate_supplier_metrics(start_date, end_date)
        daily_trends = calculate_daily_trends(start_date, end_date)

        render json: {
          overall_metrics: overall_metrics,
          user_metrics: user_metrics,
          supplier_metrics: supplier_metrics,
          daily_trends: daily_trends
        }
        rescue StandardError => e
          Rails.logger.error "Error in summary dashboard: #{e.message}"
          Rails.logger.error e.backtrace.join("\n")
          render json: { error: "Failed to fetch summary data: #{e.message}" }, status: :internal_server_error
        end
      end

      private

      def calculate_overall_metrics(start_date, end_date)
        entries = ProdEntry.where(date: start_date..end_date)

        {
          total_entries: entries.count,
          auto_mapping: {
            accepted: entries.sum(:accepted),
            dismissed: entries.sum(:dismissed),
            total: entries.sum('COALESCE(accepted, 0) + COALESCE(dismissed, 0)')
          },
          manual_mapping: {
            manually_mapped: entries.sum(:manually_mapped),
            incorrect_data: entries.sum(:incorrect_supplier_data),
            insufficient_info: entries.sum(:insufficient_info),
            created_property: entries.sum(:created_property),
            total: entries.sum('COALESCE(manually_mapped, 0) + COALESCE(incorrect_supplier_data, 0) + COALESCE(insufficient_info, 0) + COALESCE(created_property, 0)')
          },
          duplicates: entries.sum(:duplicate),
          productivity_rate: calculate_productivity_rate(entries)
        }
      end

      def calculate_user_metrics(users, start_date, end_date)
        users.map do |user|
          entries = ProdEntry.where(assigned_user: user, date: start_date..end_date)
          
          {
            user_id: user.id,
            name: user.name,
            metrics: {
              auto_total: entries.sum('COALESCE(accepted, 0) + COALESCE(dismissed, 0)'),
              manual_total: entries.sum('COALESCE(manually_mapped, 0) + COALESCE(incorrect_supplier_data, 0) + COALESCE(insufficient_info, 0) + COALESCE(created_property, 0)'),
              duplicates: entries.sum(:duplicate),
              productivity_rate: calculate_productivity_rate(entries)
            },
            daily_averages: calculate_daily_average(entries)
          }
        end
      end

      def calculate_supplier_metrics(start_date, end_date)
        Supplier.includes(:prod_entries)
               .where(prod_entries: { date: start_date..end_date })
               .map do |supplier|
          entries = supplier.prod_entries.where(date: start_date..end_date)
          
          {
            supplier_id: supplier.id,
            name: supplier.name,
            metrics: {
              total_requests: supplier.total_requests,
              total_mapped: supplier.total_mapped,
              automapping_covered: supplier.automapping_covered_total,
              manual_total: supplier.manual_total,
              duplicate_count: supplier.duplicate_count,
              not_covered: supplier.not_covered
            },
            daily_progress: calculate_supplier_daily_progress(entries)
          }
        end
      end

      def calculate_daily_trends(start_date, end_date)
        ProdEntry.where(date: start_date..end_date)
                .group(:date)
                .select(
                  'date',
                  'SUM(COALESCE(accepted, 0)) + SUM(COALESCE(dismissed, 0)) as auto_total',
                  'SUM(COALESCE(manually_mapped, 0)) + SUM(COALESCE(incorrect_supplier_data, 0)) + SUM(COALESCE(insufficient_info, 0)) + SUM(COALESCE(created_property, 0)) as manual_total',
                  'SUM(COALESCE(duplicate, 0)) as duplicates'
                )
                .map do |day|
          {
            date: day.date.strftime('%Y-%m-%d'),
            auto_total: day.auto_total,
            manual_total: day.manual_total,
            duplicates: day.duplicates,
            total: day.auto_total + day.manual_total
          }
        end
      end

      def calculate_productivity_rate(entries)
        return 0 if entries.empty?
        
        work_days = entries.pluck(:date).uniq.count
        total_entries = entries.sum('COALESCE(accepted, 0) + COALESCE(dismissed, 0) + COALESCE(manually_mapped, 0) + COALESCE(incorrect_supplier_data, 0) + COALESCE(insufficient_info, 0) + COALESCE(created_property, 0)')
        
        work_days > 0 ? (total_entries.to_f / work_days).round(2) : 0
      end

      def calculate_daily_average(entries)
        return 0 if entries.empty?
        
        entries.group(:date)
               .select(
                 'date',
                 'SUM(COALESCE(accepted, 0)) + SUM(COALESCE(dismissed, 0)) as auto_total',
                 'SUM(COALESCE(manually_mapped, 0)) + SUM(COALESCE(incorrect_supplier_data, 0)) + SUM(COALESCE(insufficient_info, 0)) + SUM(COALESCE(created_property, 0)) as manual_total'
               )
               .map do |day|
          {
            date: day.date.strftime('%Y-%m-%d'),
            total: day.auto_total + day.manual_total
          }
        end
      end

      def calculate_supplier_daily_progress(entries)
        entries.group(:date)
               .select(
                 'date',
                 'COUNT(*) as total_entries',
                 'SUM(COALESCE(accepted, 0) + COALESCE(dismissed, 0)) as auto_mapped',
                 'SUM(COALESCE(manually_mapped, 0) + COALESCE(incorrect_supplier_data, 0) + COALESCE(insufficient_info, 0) + COALESCE(created_property, 0)) as manual_mapped',
                 'SUM(COALESCE(duplicate, 0)) as duplicates'
               )
               .map do |day|
          {
            date: day.date.strftime('%Y-%m-%d'),
            total_entries: day.total_entries,
            auto_mapped: day.auto_mapped,
            manual_mapped: day.manual_mapped,
            duplicates: day.duplicates
          }
        end
      end
    end
  end
end
