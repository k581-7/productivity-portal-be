class Api::V1::UsersController < ApplicationController
  before_action :authorize_dev!, only: [:index, :update_role]

  def index
    users = User.all.order(:email)
    render json: users.as_json(only: [:id, :name, :email, :role])
  end

  def update_role
    user = User.find(params[:id])
    if user.update(role: params[:role])
      render json: { message: 'Role updated', user: user }
    else
      render json: { error: 'Update failed' }, status: :unprocessable_entity
    end
  end

  def current
    if current_user
      render json: {
        id: current_user.id,
        name: current_user.name,
        email: current_user.email,
        role: current_user.role
      }
    else
      render json: { error: 'Unauthorized' }, status: :unauthorized
    end
  end

  private

  def authorize_dev!
    unless current_user&.role == 'developer'
      render json: { error: 'Forbidden' }, status: :forbidden
    end
  end
end
