# app/controllers/api/v1/suppliers_controller.rb
module Api
  module V1
    class SuppliersController < ApplicationController
      before_action :authenticate_user!
      before_action :set_supplier, only: [:show, :update, :destroy]
      before_action :authorize_developer_or_leader!

      def index
        @suppliers = Supplier.all
        render json: @suppliers
      end

      def show
        render json: @supplier
      end

      def create
        @supplier = Supplier.new(supplier_params)
        @supplier.user = current_user

        if @supplier.save
          render json: @supplier, status: :created
        else
          render json: { errors: @supplier.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        # Both leader and developer can edit any supplier
        if current_user.leader? || current_user.developer? || @supplier.user == current_user
          if @supplier.update(supplier_params)
            render json: @supplier
          else
            render json: { errors: @supplier.errors.full_messages }, status: :unprocessable_entity
          end
        else
          render json: { error: "You are not authorized to edit this supplier" }, status: :forbidden
        end
      end

      def destroy
        # Both leader and developer can delete any supplier
        if current_user.leader? || current_user.developer? || @supplier.user == current_user
          @supplier.destroy
          head :no_content
        else
          render json: { error: "You are not authorized to delete this supplier" }, status: :forbidden
        end
      end

      private

      def set_supplier
        @supplier = Supplier.find(params[:id])
      end

      def supplier_params
        params.require(:supplier).permit(:name, :start_date, :priority, :status)
      end

      def authorize_developer_or_leader!
        unless current_user.developer? || current_user.leader?
          render json: { error: "Access denied" }, status: :forbidden
        end
      end
    end
  end
end
