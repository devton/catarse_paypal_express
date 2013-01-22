ActiveMerchant::Billing::PaypalExpressGateway.default_currency = 'BRL'
ActiveMerchant::Billing::Base.mode = :test if (::Configuration[:paypal_test] == 'true')
