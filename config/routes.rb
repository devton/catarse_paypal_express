CatarsePaypalExpress::Engine.routes.draw do
  namespace :payment do
    match '/paypal_express/:id/notifications' => 'paypal_express#notifications',  :as => 'notifications_paypal_express'
    match '/paypal_express/:id/pay'           => 'paypal_express#pay',            :as => 'pay_paypal_express'
    match '/paypal_express/:id/success'       => 'paypal_express#success',        :as => 'success_paypal_express'
    match '/paypal_express/:id/cancel'        => 'paypal_express#cancel',         :as => 'cancel_paypal_express'
  end
end

