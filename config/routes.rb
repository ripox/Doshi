
# ============================================================================
# FILE: config/routes.rb
# ============================================================================
Rails.application.routes.draw do
  root 'rounds#index'
  
  resources :rounds, only: [:index, :show, :new, :create] do
    collection do
      get :all
    end
    
    resources :deposits, only: [:index, :new, :create] do
      member do
        get :landing
      end
    end
  end
  
  post 'deposits/report', to: 'deposits#report', as: :deposit_report
  get 'stats', to: 'stats#index', as: :stats
  get 'up', to: 'rails/health#show', as: :rails_health_check
end