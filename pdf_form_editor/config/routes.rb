Rails.application.routes.draw do
  devise_for :users

  resources :pdf_documents do
    member do
      post :add_text
      post :add_signature
      post :add_multiple_elements
      get :download
      get :stream
      get :simple_edit
      get :basic_view
      get :embed_view
      get :overlay_edit
    end
  end

  root "home#index"

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by uptime monitoring tools, APMs, health check endpoints, or other automated systems.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
end
