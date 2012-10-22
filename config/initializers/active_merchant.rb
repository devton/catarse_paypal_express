ActiveMerchant::Billing::Base.mode = :test if (::Configuration[:paypal_test] == 'true')
