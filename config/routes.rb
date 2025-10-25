Rails.application.routes.draw do
  get '/auth/:provider/callback', to: 'sessions#create'
  get '/current_user', to: 'sessions#show'

  namespace :api do
    namespace :v1 do
      get '/current_user', to: 'users#current'
      
      # Suppliers with summary endpoint
      resources :suppliers do
        collection do
          get 'summary'
        end
      end
      
      # Daily Prods endpoints (NEW)
      resources :daily_prods, only: [:index] do
        collection do
          get 'summary'
          patch 'update_cell'
          delete 'delete_status'
        end
      end
      
      # Prod Entries
      resources :prod_entries, only: [:create, :index]
      
      # Summary dashboard
      get 'summary/dashboard', to: 'summary#dashboard'
      
      # Users
      get 'users', to: 'users#index'
      patch 'users/:id', to: 'users#update_role'
    end
  end
end
