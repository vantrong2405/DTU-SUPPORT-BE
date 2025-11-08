# frozen_string_literal: true

Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # OAuth routes
  namespace :oauth do
    get "google/redirect", to: "google#redirect"
    get "google/callback", to: "google#callback"
    post "logout", to: "google#logout"
  end

  # post "/logout", to: "sessions#destroy" # moved to oauth/google#logout

  resources :users, only: [:show] do
    collection do
      get :me
      delete :logout
    end
  end

  post "api/chat", to: "chats#create"

  # Payments routes
  resources :payments, only: %i[index show create update destroy]

  # Webhooks routes
  namespace :webhooks do
    post "senpay", to: "senpay#callback"
  end

  # Defines the root path route ("/")
  # root "posts#index"
end
