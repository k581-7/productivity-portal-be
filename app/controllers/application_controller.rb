class ApplicationController < ActionController::API
  def current_user
    header = request.headers['Authorization']
    token = header&.split(' ')&.last

    return nil unless token

    begin
      decoded = JWT.decode(token, Rails.application.credentials.secret_key_base)[0]
      # Prefer finding by user_id if present in the token, fall back to email
      if decoded['user_id']
        @current_user ||= User.find_by(id: decoded['user_id'])
      else
        @current_user ||= User.find_by(email: decoded['email'])
      end
    rescue JWT::DecodeError => e
      Rails.logger.warn "JWT decode failed: #{e.message}"
      nil
    end
  end

  def authenticate_user!
    unless current_user
      render json: { error: 'Unauthorized' }, status: :unauthorized
    end
  end

  # ============================================================
  # ROLE-BASED AUTHORIZATION METHODS
  # ============================================================
  
  # Developer only
  def authorize_developer!
    unless current_user&.developer?
      render json: { error: 'Access denied. Developer role required.' }, status: :forbidden
    end
  end

  # Leader only
  def authorize_leader!
    unless current_user&.leader?
      render json: { error: 'Access denied. Leader role required.' }, status: :forbidden
    end
  end

  # Developer or Leader
  def authorize_developer_or_leader!
    unless current_user&.developer? || current_user&.leader?
      render json: { error: 'Access denied. Leader or Developer role required.' }, status: :forbidden
    end
  end

  # Everyone except Junior (Guest, Leader, Developer)
  def authorize_not_junior!
    if current_user&.junior?
      render json: { error: 'Access denied. Junior role does not have access to this resource.' }, status: :forbidden
    end
  end

  # Junior, Leader, or Developer (excludes Guest)
  def authorize_junior_or_higher!
    if current_user&.guest?
      render json: { error: 'Access denied. Guest role does not have access to this resource.' }, status: :forbidden
    end
  end

  # Check if user can edit (Developer or Leader only)
  def authorize_can_edit!
    unless current_user&.developer? || current_user&.leader?
      render json: { error: 'Access denied. You do not have permission to edit this resource.' }, status: :forbidden
    end
  end

  # Check if user is approved and not disabled
  def check_user_status!
    if current_user && (current_user.disabled? || !current_user.approved?)
      render json: { error: 'Your account is not active. Please contact an administrator.' }, status: :forbidden
    end
  end
end