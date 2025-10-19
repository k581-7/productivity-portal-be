module Api
  module V1
    class ProdEntriesController < ApplicationController
      before_action :authenticate_user!

      def index
        # Leaders and developers can see all entries
        # Juniors can only see their own entries
        if current_user.leader? || current_user.developer?
          @prod_entries = ProdEntry.includes(:supplier, :assigned_user, :entered_by_user).all
        else
          @prod_entries = ProdEntry.includes(:supplier, :assigned_user, :entered_by_user)
                                   .where(assigned_user_id: current_user.id)
        end
        
        render json: @prod_entries, include: [:supplier, :assigned_user, :entered_by_user]
      end

      def create
        # Validate permissions
        assigned_user_id = prod_entry_params[:assigned_user_id] || current_user.id
        assigned_user = User.find_by(id: assigned_user_id)

        unless can_assign_to_user?(assigned_user)
          render json: { error: 'Unauthorized to create entry for this user' }, status: :forbidden
          return
        end

        @prod_entry = ProdEntry.new(prod_entry_params)
        @prod_entry.entered_by_user_id = current_user.id
        @prod_entry.assigned_user_id = assigned_user_id

        if @prod_entry.save
          # Subtract from supplier totals
          update_supplier_totals(@prod_entry)
          
          render json: @prod_entry, status: :created
        else
          render json: { errors: @prod_entry.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def prod_entry_params
        params.require(:prod_entry).permit(
          :supplier_id, :assigned_user_id, :date, :mapping_type,
          :manually_mapped, :incorrect_supplier_data, :created_property,
          :insufficient_info, :accepted, :dismissed, :no_result,
          :duplicate, :reactivated, :source, :remarks
        )
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

        # Subtract the entry values from supplier totals
        supplier.update(
          manually_mapped: (supplier.manually_mapped || 0) - (entry.manually_mapped || 0),
          incorrect_supplier_data: (supplier.incorrect_supplier_data || 0) - (entry.incorrect_supplier_data || 0),
          duplicate_count: (supplier.duplicate_count || 0) - (entry.duplicate || 0),
          created_property: (supplier.created_property || 0) - (entry.created_property || 0),
          reactivated_total: (supplier.reactivated_total || 0) - (entry.reactivated || 0),
          accepted_total: (supplier.accepted_total || 0) - (entry.accepted || 0),
          dismissed_total: (supplier.dismissed_total || 0) - (entry.dismissed || 0)
        )
      end
    end
  end
end