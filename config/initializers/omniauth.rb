# Disable CSRF check for OmniAuth in API-only apps
OmniAuth.config.allowed_request_methods = [:post, :get]
OmniAuth.config.silence_get_warning = true
OmniAuth.config.request_validation_phase = proc { |env| true }

Rails.application.config.middleware.use OmniAuth::Builder do
  provider :google_oauth2,
    ENV['GOOGLE_CLIENT_ID'],
    ENV['GOOGLE_CLIENT_SECRET'],
    {
      scope: 'email,profile',
      prompt: 'select_account',
      redirect_uri: 'http://localhost:3000/auth/google_oauth2/callback'
    }
end