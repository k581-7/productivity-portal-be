class SessionsController < ApplicationController
  include ActionController::RequestForgeryProtection
  protect_from_forgery with: :null_session

  def create
    auth = request.env['omniauth.auth']

    if auth.nil? || auth.info.nil?
      Rails.logger.warn "OmniAuth callback missing auth or info"
      render json: { error: 'Authentication failed' }, status: :unauthorized and return
    end

    user = User.find_or_initialize_by(email: auth.info.email)
    user.name ||= auth.info.name
    user.role ||= 'guest'
    user.save!

    session[:user_id] = user.id
    redirect_to "#{ENV['FRONTEND_URL']}/dashboard"
  rescue => e
    Rails.logger.error "OAuth session creation failed: #{e.message}"
    render json: { error: 'Login error' }, status: :internal_server_error
  end
end