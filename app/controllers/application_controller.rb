class ApplicationController < ActionController::API
  def current_user
    header = request.headers['Authorization']
    token = header.split(' ').last if header
    decoded = JWT.decode(token, Rails.application.credentials.secret_key_base)[0]
    @current_user ||= User.find(decoded['user_id'])
  rescue
    nil
  end

  def authorize_leader!
    render json: { error: 'Forbidden' }, status: :forbidden unless current_user&.leader?
  end
end
