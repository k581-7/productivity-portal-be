module Api
  module V1
    class SuppliersController < ApplicationController
      before_action :authenticate_user!
      before_action :set_supplier, only: [:show, :update, :destroy]  # Add this line
      before_action :authorize_developer_or_leader!, only: [:create, :update, :destroy]

      def index
        suppliers = Supplier.includes(:assigned_pic).order(created_at: :desc)
        render json: suppliers.as_json(include: { assigned_pic: { only: [:id, :name, :email] } })
      end

      def show
        render json: @supplier
      end

      def create
        @supplier = Supplier.new(supplier_params)
        @supplier.assigned_pic_id = current_user.id

        if @supplier.save
          render json: @supplier, status: :created
        else
          render json: { errors: @supplier.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        if @supplier.update(supplier_params)
          render json: @supplier
        else
          render json: { errors: @supplier.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        @supplier.destroy
        head :no_content
      end

      def summary
        # Get date range
        start_date = params[:start_date] ? Date.parse(params[:start_date]) : Date.today.beginning_of_month
        end_date = params[:end_date] ? Date.parse(params[:end_date]) : Date.today.end_of_month
        
        suppliers = Supplier.where(start_date: start_date..end_date).order(:start_date)
        
        # Group by supplier for trend analysis
        supplier_data = suppliers.map do |supplier|
          {
            name: supplier.name,
            manual_mapping: supplier.manual_total || 0,
            auto_mapping: (supplier.accepted_total || 0) + (supplier.dismissed_total || 0),
            duplicates: supplier.duplicate_count || 0,
            created_property: supplier.created_property || 0
          }
        end
        
        # Calculate overall totals
        totals = {
          manual_mapping: suppliers.sum { |s| s.manual_total || 0 },
          auto_mapping: suppliers.sum { |s| (s.accepted_total || 0) + (s.dismissed_total || 0) },
          duplicates: suppliers.sum { |s| s.duplicate_count || 0 },
          cannot_be_mapped: suppliers.sum { |s| s.incorrect_supplier_data || 0 },
          created_property: suppliers.sum { |s| s.created_property || 0 }
        }
        
        render json: {
          labels: supplier_data.map { |s| s[:name] },
          manual_mapping: supplier_data.map { |s| s[:manual_mapping] },
          auto_mapping: supplier_data.map { |s| s[:auto_mapping] },
          duplicates: supplier_data.map { |s| s[:duplicates] },
          created_property: supplier_data.map { |s| s[:created_property] },
          totals: totals
        }
      end

      private

      def set_supplier
        @supplier = Supplier.find(params[:id])
      end

      def supplier_params
        params.require(:supplier).permit(
          :name, :request_date, :start_date, :completed_date,
          :priority, :requester, :status, :total_requests,
          :total_mapped, :total_pending, :automapping_covered_total,
          :suggestions_total, :accepted_total, :dismissed_total,
          :manual_total, :manually_mapped, :incorrect_supplier_data,
          :duplicate_count, :created_property, :not_covered,
          :nc_manually_mapped, :nc_created_property, :nc_incorrect_supplier,
          :jp_props, :reactivated_total, :remarks
        )
      end

      def authorize_developer_or_leader!
        unless current_user.developer? || current_user.leader?
          render json: { error: "Access denied" }, status: :forbidden
        end
      end
    end
  end
end