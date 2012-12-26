PaymentEngines.register({name: 'paypal', review_path: ->(backer){ CatarsePaypalExpress::Engine.routes.url_helpers.payment_review_paypal_express_path(backer) }, locale: 'en'})
