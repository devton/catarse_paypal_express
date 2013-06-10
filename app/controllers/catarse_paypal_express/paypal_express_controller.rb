class CatarsePaypalExpress::PaypalExpressController < ApplicationController
  skip_before_filter :force_http
  SCOPE = "projects.backers.checkout"
  layout :false

  def review
  end

  def ipn
    if backer
      process_paypal_message params
      backer.update_attributes({
        :payment_service_fee => params['mc_fee'],
        :payer_email => params['payer_email']
      })
    else
      return render status: 500, text: e.inspect
    end
    return render status: 200, nothing: true
  rescue Exception => e
    return render status: 500, text: e.inspect
  end

  def pay
    begin
      response = gateway.setup_purchase(backer.price_in_cents, {
        ip: request.remote_ip,
        return_url: success_paypal_expres_url(id: backer.id),
        cancel_return_url: cancel_paypal_expres_url(id: backer.id),
        currency_code: 'BRL',
        description: t('paypal_description', scope: SCOPE, :project_name => backer.project.name, :value => backer.display_value),
        notify_url: ipn_paypal_express_url
      })

      process_paypal_message response.params
      backer.update_attributes payment_method: 'PayPal', payment_token: response.token

      redirect_to gateway.redirect_url_for(response.token)
    rescue Exception => e
      Rails.logger.info "-----> #{e.inspect}"
      flash[:failure] = t('paypal_error', scope: SCOPE)
      return redirect_to main_app.new_project_backer_path(backer.project)
    end
  end

  def success
    begin
      purchase = gateway.purchase(backer.price_in_cents, {
        ip: request.remote_ip,
        token: backer.payment_token,
        payer_id: params[:PayerID]
      })

      # we must get the deatils after the purchase in order to get the transaction_id
      process_paypal_message purchase.params
      backer.update_attributes payment_id: purchase.params['transaction_id'] if purchase.params['transaction_id'] 

      flash[:success] = t('success', scope: SCOPE)
      redirect_to main_app.project_backer_path(project_id: backer.project.id, id: backer.id)
    rescue Exception => e
      Rails.logger.info "-----> #{e.inspect}"
      flash[:failure] = t('paypal_error', scope: SCOPE)
      return redirect_to main_app.new_project_backer_path(backer.project)
    end
  end

  def cancel
    flash[:failure] = t('paypal_cancel', scope: SCOPE)
    redirect_to main_app.new_project_backer_path(backer.project)
  end

  def backer
    @backer ||= (params['id'] ? PaymentEngines.find_payment(id: params['id']) : PaymentEngines.find_payment(payment_id: params['txn_id']))
  end

  def process_paypal_message(data)
    extra_data = (data['charset'] ? JSON.parse(params.to_json.force_encoding(data['charset']).encode('utf-8')) : data)
    PaymentEngines.create_payment_notification backer_id: backer.id, extra_data: extra_data

    if data["checkout_status"] == 'PaymentActionCompleted'
      backer.confirm! 
    elsif data["payment_status"]
      case data["payment_status"].downcase
      when 'completed'
        backer.confirm! 
      when 'refunded'
        backer.refund!
      when 'canceled_reversal'
        backer.cancel!
      when 'expired', 'denied'
        backer.pendent! 
      else
        backer.waiting! if backer.pending?
      end
    end
  end

  def gateway
    if PaymentEngines.configuration[:paypal_username] and PaymentEngines.configuration[:paypal_password] and PaymentEngines.configuration[:paypal_signature]
      @gateway ||= ActiveMerchant::Billing::PaypalExpressGateway.new({
        login: PaymentEngines.configuration[:paypal_username],
        password: PaymentEngines.configuration[:paypal_password],
        signature: PaymentEngines.configuration[:paypal_signature]
      })
    else
      puts "[PayPal] An API Certificate or API Signature is required to make requests to PayPal"
    end
  end
end
