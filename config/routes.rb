CatarsePaypalExpress::Engine.routes.draw do
  resources :paypal_express, only: [], path: 'payment/paypal_express' do
    collection do
      post 'notifications' => 'paypal_express#ipn', :as => 'ipn_paypal_express'
    end
    member do
      get   :review
      match :notifications
      match :pay
      match :success
      match :cancel
    end
  end
end

