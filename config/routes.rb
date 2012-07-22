CatarsePaypalExpress::Engine.routes.draw do
  namespace :payment do
    resources :paypal_express, only: [] do
      member do
        get :pay
        get :success
        get :error
      end

      collection do
        post :notifications
      end
    end
  end
end

