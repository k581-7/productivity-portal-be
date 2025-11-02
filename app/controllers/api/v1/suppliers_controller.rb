module Api
  module V1
    class SuppliersController < ApplicationController
      before_action :authenticate_user!
      before_action :check_junior_access! # Junior cannot access Suppliers at all
      before_action :set_supplier, only: [:show, :update, :destroy]  
      before_action :authorize_can_edit!, only: [:create, :update, :destroy] # Only Leader/Developer can edit

      def index
        suppliers = Supplier.includes(:assigned_pic).order(created_at: :desc)
        render json: suppliers.as_json(include: { assigned_pic: { only: [:id, :name, :email] } })
      end

      def show
        # Calculate total bad data:
        # Sum of incorrect_supplier_data + insufficient_info from all three sections + jp_props
        # NOTE: nc_incorrect_supplier already combines incorrect + insufficient, so don't double count
        total_bad_data = (
          (@supplier.incorrect_supplier_data || 0) + (@supplier.insufficient_info || 0) +  # Manual Mapping: 1 + 2 = 3
          (@supplier.nc_incorrect_supplier || 0) +  # Not Covered (already combines both): 2
          (@supplier.bs_incorrect_supplier_data || 0) + (@supplier.bs_insufficient_info || 0) +  # Bad Suggestions: 0 + 1 = 1
          (@supplier.jp_props || 0)  # JP Properties: 3
        )
        
        # Calculate total mapped:
        # Sum of: Accepted (Automapping) + Manually Mapped + Created Property from all three sections + Automapping Covered
        total_mapped = (
          (@supplier.accepted_total || 0) +  # Automapping: Accepted
          (@supplier.manually_mapped || 0) + (@supplier.created_property || 0) +  # Manual Mapping
          (@supplier.nc_manually_mapped || 0) + (@supplier.nc_created_property || 0) +  # Not Covered
          (@supplier.bs_manually_mapped || 0) + (@supplier.bs_created_property || 0) +  # Bad Suggestions
          (@supplier.automapping_covered_total || 0)  # Others: Automapping Covered
        )
        
        # Calculate total pending:
        # Total Requests - Total Mapped
        total_pending = (@supplier.total_requests || 0) - total_mapped
        
        Rails.logger.info "TOTAL BAD DATA CALCULATION: Manual(#{@supplier.incorrect_supplier_data}+#{@supplier.insufficient_info}=#{(@supplier.incorrect_supplier_data||0)+(@supplier.insufficient_info||0)}), NC(#{@supplier.nc_incorrect_supplier}), BS(#{@supplier.bs_incorrect_supplier_data}+#{@supplier.bs_insufficient_info}=#{(@supplier.bs_incorrect_supplier_data||0)+(@supplier.bs_insufficient_info||0)}), JP(#{@supplier.jp_props}) = #{total_bad_data}"
        Rails.logger.info "TOTAL MAPPED CALCULATION: Accepted(#{@supplier.accepted_total}), Manual(#{@supplier.manually_mapped}+#{@supplier.created_property}), NC(#{@supplier.nc_manually_mapped}+#{@supplier.nc_created_property}), BS(#{@supplier.bs_manually_mapped}+#{@supplier.bs_created_property}), AutoCovered(#{@supplier.automapping_covered_total}) = #{total_mapped}"
        Rails.logger.info "TOTAL PENDING CALCULATION: Total Requests(#{@supplier.total_requests}) - Total Mapped(#{total_mapped}) = #{total_pending}"
        
        supplier_data = @supplier.as_json
        supplier_data['total_bad_data'] = total_bad_data
        supplier_data['total_mapped'] = total_mapped
        supplier_data['total_pending'] = total_pending
        
        render json: supplier_data
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
          :insufficient_info, :duplicate_count, :created_property, :not_covered,
          :nc_manually_mapped, :nc_created_property, :nc_incorrect_supplier, :nc_reactivated_total,
          :bs_manually_mapped, :bs_incorrect_supplier_data, :bs_insufficient_info, 
          :bs_created_property, :bs_reactivated_total,
          :jp_props, :reactivated_total, :remarks
        )
      end

      # Junior role should NOT have access to Suppliers
      def check_junior_access!
        if current_user&.junior?
          render json: { error: 'Access denied. Junior role does not have access to Suppliers.' }, status: :forbidden
        end
      end
    end
  end
end