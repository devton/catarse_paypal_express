ActiveMerchant::Billing::PaypalExpressGateway.default_currency = 'BRL'
ActiveMerchant::Billing::Base.mode = :test if (PaymentEngines.configuration[:paypal_test] == 'true' rescue nil)
