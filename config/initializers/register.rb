begin
  PaymentEngines.register({
    name: 'paypal',
    review_path: ->(contribution) {
      CatarsePaypalExpress::Engine.routes.url_helpers.review_paypal_express_path(contribution)
    },
    can_do_refund?: true,
    direct_refund: ->(contribution) {
      CatarsePaypalExpress::ContributionActions.new(contribution).refund
    },
    locale: 'en'
  })
rescue Exception => e
  puts "Error while registering payment engine: #{e}"
end
