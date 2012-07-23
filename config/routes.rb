CatarsePaypalExpress::Engine.routes.draw do
  namespace :payment do
    get '/paypal_express/:id/notifications' => 'paypal_express#notifications', :as => 'notifications_paypal_express'
    #resources :paypal_express, only: [] do
      #member do
        ##get :pay
        ##get :success
        ##get :error
        #match :notifications
      #end
    #end
  end
end

