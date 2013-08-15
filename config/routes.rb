CatarsePaypalExpress::Engine.routes.draw do
  resources :paypal_express, only: [], path: 'payment/paypal_express' do
    collection do
      post :ipn
    end

    member do
      get  :review
      post :pay
      get  :success
      get  :cancel
    end
  end
end

