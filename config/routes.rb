Rails.application.routes.draw do
  get '/auth/:provider/callback', to: 'sessions#create'
  get '/current_user', to: 'sessions#show'

  namespace :api do
    namespace :v1 do
      get '/current_user', to: 'users#current'
      resources :suppliers
      resources :prod_entries
      get 'users', to: 'users#index'
      patch 'users/:id', to: 'users#update_role'
    end
  end
end

