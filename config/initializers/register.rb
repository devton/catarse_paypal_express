begin
  PaymentEngines.register({
    name: 'paypal',
    review_path: ->(backer) {
      CatarsePaypalExpress::Engine.routes.url_helpers.review_paypal_express_path(backer)
    },
    refund_path: ->(backer) {
      CatarsePaypalExpress::Engine.routes.url_helpers.refund_paypal_express_path(backer)
    },
    locale: 'en'
  })
rescue Exception => e
  puts "Error while registering payment engine: #{e}"
end
