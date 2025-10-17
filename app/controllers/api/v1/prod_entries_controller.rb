class Api::V1::ProdEntriesController < ApplicationController
  before_action :set_prod_entry, only: [:show, :update, :destroy]

  # GET /api/v1/prod_entries
  def index
    prod_entries = ProdEntry.includes(:supplier, :entered_by_user, :assigned_user).order(date: :desc)
    render json: prod_entries.as_json(include: [:supplier, :entered_by_user, :assigned_user])
  end

  # GET /api/v1/prod_entries/:id
  def show
    render json: @prod_entry.as_json(include: [:supplier, :entered_by_user, :assigned_user])
  end

  # POST /api/v1/prod_entries
  def create
    prod_entry = ProdEntry.new(prod_entry_params)
    prod_entry.entered_by_user = current_user

    if prod_entry.save
      render json: prod_entry, status: :created
    else
      render json: { errors: prod_entry.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /api/v1/prod_entries/:id
  def update
    if @prod_entry.update(prod_entry_params)
      render json: @prod_entry
    else
      render json: { errors: @prod_entry.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /api/v1/prod_entries/:id
  def destroy
    @prod_entry.destroy
    render json: { message: 'Prod entry was successfully deleted.' }, status: :ok
  end

  private

  def set_prod_entry
    @prod_entry = ProdEntry.find(params[:id])
  end

  def prod_entry_params
    params.require(:prod_entry).permit(
      :supplier_id, :assigned_user_id, :date, :mapping_type, :manually_mapped,
      :incorrect_supplier_data, :created_property, :insufficient_info,
      :accepted, :dismissed, :no_result, :duplicate, :reactivated,
      :source, :remarks
    )
  end
end