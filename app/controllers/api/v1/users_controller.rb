class Api::V1::UsersController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_developer!, only: [:index, :pending, :approve, :disable, :activate, :update_role]

  # GET /api/v1/users - Only developers can see user list
  def index
    users = User.where(approved: true).order(:email)
    render json: users.as_json(only: [:id, :name, :email, :role, :approved, :disabled])
  end

  # GET /api/v1/users/pending - Only developers can see pending users
  def pending
    users = User.where(approved: false, disabled: [false, nil]).order(:created_at)
    render json: users.as_json(only: [:id, :name, :email, :role, :approved, :disabled])
  end

  # PATCH /api/v1/users/:id/approve - Only developers can approve users
  def approve
    user = User.find(params[:id])
    if user.update(approved: true)
      render json: { message: 'User approved', user: user }
    else
      render json: { error: 'Approval failed' }, status: :unprocessable_entity
    end
  end

  # PATCH /api/v1/users/:id/disable - Only developers can disable users
  def disable
    user = User.find(params[:id])
    if user.update(disabled: true)
      render json: { message: 'User disabled', user: user }
    else
      render json: { error: 'Disable failed' }, status: :unprocessable_entity
    end
  end

  # PATCH /api/v1/users/:id/activate - Only developers can activate users
  def activate
    user = User.find(params[:id])
    if user.update(disabled: false)
      render json: { message: 'User activated', user: user }
    else
      render json: { error: 'Activate failed' }, status: :unprocessable_entity
    end
  end

  # PATCH /api/v1/users/:id - Only developers can update user roles
  def update_role
    user = User.find(params[:id])
    if user.update(role: params[:role])
      render json: { message: 'Role updated', user: user }
    else
      render json: { error: 'Update failed' }, status: :unprocessable_entity
    end
  end

  # GET /api/v1/users/current - All authenticated users can see their own info
  def current
    if current_user
      render json: {
        id: current_user.id,
        name: current_user.name,
        email: current_user.email,
        role: current_user.role,
        picture: current_user.picture
      }
    else
      render json: { error: 'Unauthorized' }, status: :unauthorized
    end
  end
end
