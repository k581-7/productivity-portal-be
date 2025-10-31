module Api
  module V1
    class AuthController < ApplicationController
      skip_before_action :verify_authenticity_token
      
      def google
        auth = request.env['omniauth.auth']
        
        if auth.nil?
          render json: { error: "Authentication failed" }, status: :unauthorized
          return
        end

        user = User.find_or_create_by(email: auth['info']['email']) do |u|
          u.name = auth['info']['name'] || auth['info']['email'].split('@').first
          u.google_id = auth['uid']
          u.role = 'junior'
          u.approved = false
        end

        if user.disabled?
          render json: { error: "Account disabled" }, status: :forbidden
        elsif !user.approved?
          render json: { error: "Access not granted. Please wait for approval." }, status: :forbidden
        elsif user.persisted?
          session[:user_id] = user.id
          # Redirect to frontend or return JSON
          render json: { 
            user: {
              id: user.id,
              name: user.name,
              email: user.email,
              role: user.role
            },
            message: "Logged in successfully" 
          }
        else
          render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
        end
      end
    end
  end
end