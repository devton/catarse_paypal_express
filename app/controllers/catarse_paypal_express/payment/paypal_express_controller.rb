module CatarsePaypalExpress::Payment
  class PaypalExpressController < ApplicationController
    before_filter :setup_gateway

    def notifications
      backer = Backer.find params[:id]
      response = @@gateway.details_for(backer.payment_token)
      if response.params['transaction_id'] == params['txn_id']
        backer.confirm! if response.success?
        render status: 200, nothing: true
      else
        render status: 404, nothing: true
      end
    rescue
      render status: 404, nothing: true
    end

  private

    def setup_gateway
      if ::Configuration[:paypal_username] and ::Configuration[:paypal_password] and ::Configuration[:paypal_signature]
        @@gateway ||= ActiveMerchant::Billing::PaypalExpressGateway.new({
          :login => ::Configuration[:paypal_username],
          :password => ::Configuration[:paypal_password],
          :signature => ::Configuration[:paypal_signature]
        })
      else
        puts "[PayPal] An API Certificate or API Signature is required to make requests to PayPal"
      end
    end
  end
end
