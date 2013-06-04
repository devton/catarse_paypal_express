Rails.application.routes.draw do

  mount CatarsePaypalExpress::Engine => "/catarse_paypal_express"
end
