module Api
  module V1
    class AuthController < ApplicationController
      
      def google
        auth = request.env['omniauth.auth']

        # If OAuth data is present, use it
        if auth.present?
          email = auth['info']['email']
          name = auth['info']['name'] || email.split('@').first
          google_id = auth['uid']
        else
          # Fallback: allow manual login via JSON body (for Postman)
          email = params[:email]
          name = params[:name] || email&.split('@')&.first
          google_id = params[:uid]
        end

        if email.blank?
          render json: { error: "Authentication failed" }, status: :unauthorized and return
        end

        user = User.find_or_create_by(email: email) do |u|
          u.name = name
          u.google_id = google_id
          u.role = 'junior'
          u.approved = false
        end

        if user.disabled?
          render json: { error: "Account disabled" }, status: :forbidden and return
        end

        unless user.approved?
          render json: { error: "Access not granted. Please wait for approval." }, status: :forbidden and return
        end

        # Issue JWT token for manual login
        payload = {
          user_id: user.id,
          email: user.email,
          exp: 24.hours.from_now.to_i
        }
        token = JWT.encode(payload, Rails.application.credentials.secret_key_base)

        render json: {
          user: {
            id: user.id,
            name: user.name,
            email: user.email,
            role: user.role
          },
          token: token,
          message: "Logged in successfully"
        }
      end
    end
  end
end