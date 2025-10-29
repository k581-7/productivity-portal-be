class Api::V1::UsersController < ApplicationController
  # PATCH /api/v1/users/:id/activate
  def activate
    unless current_user.developer?
      render json: { error: 'Forbidden' }, status: :forbidden and return
    end
    user = User.find(params[:id])
    if user.update(disabled: false)
      render json: { message: 'User activated', user: user }
    else
      render json: { error: 'Activate failed' }, status: :unprocessable_entity
    end
  end
  before_action :authorize_dev!, only: [:update_role]
  before_action :authorize_dev_or_leader!, only: [:index]

  def index
    # Show all approved users, including disabled ones
    if current_user.developer?
      users = User.where(approved: true).order(:email)
    elsif current_user.leader?
      users = User.where(role: :junior, approved: true).order(:email)
    else
      users = []
    end
    render json: users.as_json(only: [:id, :name, :email, :role, :approved, :disabled])
  end

  # GET /api/v1/users/pending
  def pending
    # Only developers can see pending users
    unless current_user.developer?
      render json: { error: 'Forbidden' }, status: :forbidden and return
    end
    users = User.where(approved: false, disabled: [false, nil]).order(:created_at)
    render json: users.as_json(only: [:id, :name, :email, :role, :approved, :disabled])
  end

  # PATCH /api/v1/users/:id/approve
  def approve
    unless current_user.developer?
      render json: { error: 'Forbidden' }, status: :forbidden and return
    end
    user = User.find(params[:id])
    if user.update(approved: true)
      render json: { message: 'User approved', user: user }
    else
      render json: { error: 'Approval failed' }, status: :unprocessable_entity
    end
  end

  # PATCH /api/v1/users/:id/disable
  def disable
    unless current_user.developer?
      render json: { error: 'Forbidden' }, status: :forbidden and return
    end
    user = User.find(params[:id])
    if user.update(disabled: true)
      render json: { message: 'User disabled', user: user }
    else
      render json: { error: 'Disable failed' }, status: :unprocessable_entity
    end
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
