Rails.application.routes.draw do
  # Health check endpoint for Render.com
  get '/health', to: proc { [200, {}, ['OK']] }

  # OmniAuth callbacks - allow GET and POST for provider callbacks
  match '/auth/:provider/callback', to: 'sessions#create', via: [:get, :post]
  get '/auth/failure', to: 'sessions#failure'
  delete '/signout', to: 'sessions#destroy'

  # Session helper endpoints
  get '/current_user', to: 'sessions#show'

  namespace :api do
    namespace :v1 do
      # API authentication (used by JS clients)
      post 'auth/google', to: 'auth#google'
      get  'auth/google', to: 'auth#google' # allow GET for browser redirects if needed

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
          delete 'delete_entry'
        end
      end
      
      # Prod Entries
      resources :prod_entries, only: [:create, :index] do
        collection do
          get 'upload_history'
          delete 'delete_upload/:batch_id', action: :delete_upload
        end
      end
      
      # Summary dashboard
      get 'summary/dashboard', to: 'summary#dashboard'
      
      # Todos
      resources :todos, only: [:index, :create, :update, :destroy]
      
      # Users
      get 'users', to: 'users#index'
      get 'users/pending', to: 'users#pending'
      patch 'users/:id', to: 'users#update_role'
      patch 'users/:id/approve', to: 'users#approve'
      patch 'users/:id/disable', to: 'users#disable'
      patch 'users/:id/activate', to: 'users#activate'
    end
  end
end
