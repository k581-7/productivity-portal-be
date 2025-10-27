class Api::V1::UsersController < ApplicationController
  before_action :authorize_dev!, only: [:update_role]
  before_action :authorize_dev_or_leader!, only: [:index]

  def index
    # Developers can see all users
    # Leaders can only see junior users
    if current_user.developer?
      users = User.all.order(:email)
    elsif current_user.leader?
      users = User.where(role: :junior).order(:email)
    else
      users = []
    end
    
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

  def authorize_dev_or_leader!
    unless current_user&.developer? || current_user&.leader?
      render json: { error: 'Forbidden' }, status: :forbidden
    end
  end
end
