Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins 'http://localhost:5173' # your React/Vite frontend

    resource '*',
      headers: :any,
      methods: [:get, :post, :patch, :put, :delete, :options],
      credentials: true
  end
end