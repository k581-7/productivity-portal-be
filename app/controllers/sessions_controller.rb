class SessionsController < ApplicationController
  include ActionController::RequestForgeryProtection
  protect_from_forgery with: :null_session

  def create
    auth = request.env['omniauth.auth']

    unless auth&.info
      Rails.logger.warn "OmniAuth callback missing auth or info"
      render json: { error: 'Authentication failed' }, status: :unauthorized and return
    end

    # Bootstrap developer account - hardcoded for initial setup
    # This allows the first developer to sign in and approve other users
    # Change or remove this email after initial deployment if needed
    is_bootstrap_admin = auth.info.email == 'jinjoolane@gmail.com'

    user = User.find_or_create_by(email: auth.info.email) do |u|
      u.name = auth.info.name.presence || auth.info.email.split('@').first
      u.role = is_bootstrap_admin ? :developer : :guest  # Use symbols for enum
      u.approved = is_bootstrap_admin ? true : false
      u.picture = auth.info.image
    end
    
    # UPDATE existing users too (not just new ones)
    if is_bootstrap_admin
      user.update(role: :developer, approved: true)
    end
    
    # Update picture on subsequent logins if it changed
    if user.persisted? && auth.info.image.present? && user.picture != auth.info.image
      user.update(picture: auth.info.image)
    end

    if user.disabled?
      render json: { error: 'Account disabled' }, status: :forbidden and return
    end

    unless user.approved?
      render json: { error: 'Access not granted. Please wait for approval.' }, status: :forbidden and return
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
    Rails.logger.error e.backtrace.join("\n")  # Add full stacktrace for debugging
    render json: { error: 'Login error' }, status: :internal_server_error
  end
end