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

  def authorize_leader!
    unless current_user&.leader?
      render json: { error: 'Forbidden' }, status: :forbidden
    end
  end
end