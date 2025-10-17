class SessionsController < ApplicationController
  include ActionController::RequestForgeryProtection
  protect_from_forgery with: :null_session

  def create
    auth = request.env['omniauth.auth']

    unless auth&.info
      Rails.logger.warn "OmniAuth callback missing auth or info"
      render json: { error: 'Authentication failed' }, status: :unauthorized and return
    end

    user = User.find_or_create_by(email: auth.info.email) do |u|
      u.name = auth.info.name.presence || auth.info.email.split('@').first
      u.role = 'guest'
    end

    payload = {
      user_id: user.id,
      email: user.email,
      exp: 24.hours.from_now.to_i
    }

    token = JWT.encode(payload, Rails.application.credentials.secret_key_base)

    redirect_to "#{ENV['FRONTEND_URL']}/dashboard?token=#{URI.encode_www_form_component(token)}"
  rescue => e
    Rails.logger.error "OAuth session creation failed: #{e.message}"
    render json: { error: 'Login error' }, status: :internal_server_error
  end
end