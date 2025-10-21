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