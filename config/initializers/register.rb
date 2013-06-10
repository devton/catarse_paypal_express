begin
  PaymentEngines.register({name: 'paypal', review_path: ->(backer){ CatarsePaypalExpress::Engine.routes.url_helpers.review_paypal_expres_path(backer) }, locale: 'en'})
rescue Exception => e
  puts "Error while registering payment engine: #{e}"
end
