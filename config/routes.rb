Rails.application.routes.draw do
  get '/auth/:provider/callback', to: 'sessions#create'
  get '/current_user', to: 'sessions#show'

  namespace :api do
    namespace :v1 do
      resources :suppliers
    end
  end
end

