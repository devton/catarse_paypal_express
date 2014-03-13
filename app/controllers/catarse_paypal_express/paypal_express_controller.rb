class CatarsePaypalExpress::PaypalExpressController < ApplicationController
  include ActiveMerchant::Billing::Integrations

  skip_before_filter :force_http
  SCOPE = "projects.contributions.checkout"
  layout :false

  def review
  end

  def refund
    refund_request = gateway.refund(nil, contribution.payment_id)


    if refund_request.success?
      flash[:notice] = I18n.t('projects.contributions.refund.success')
    else
      flash[:alert] = refund_request.try(:message) || I18n.t('projects.contributions.refund.error')
    end

    redirect_to main_app.admin_contributions_path
  end

  def ipn
    if contribution && notification.acknowledge && (contribution.payment_method == 'PayPal' || contribution.payment_method.nil?)
      process_paypal_message params
      contribution.update_attributes({
        :payment_service_fee => params['mc_fee'],
        :payer_email => params['payer_email']
      })
    else
      return render status: 500, nothing: true
    end
    return render status: 200, nothing: true
  rescue Exception => e
    return render status: 500, text: e.inspect
  end

  def pay
    begin
      response = gateway.setup_purchase(contribution.price_in_cents, {
        ip: request.remote_ip,
        return_url: success_paypal_express_url(id: contribution.id),
        cancel_return_url: cancel_paypal_express_url(id: contribution.id),
        currency_code: 'BRL',
        description: t('paypal_description', scope: SCOPE, :project_name => contribution.project.name, :value => contribution.display_value),
        notify_url: ipn_paypal_express_index_url
      })

      process_paypal_message response.params
      contribution.update_attributes payment_method: 'PayPal', payment_token: response.token

      redirect_to gateway.redirect_url_for(response.token)
    rescue Exception => e
      Rails.logger.info "-----> #{e.inspect}"
      flash[:failure] = t('paypal_error', scope: SCOPE)
      return redirect_to main_app.new_project_contribution_path(contribution.project)
    end
  end

  def success
    begin
      purchase = gateway.purchase(contribution.price_in_cents, {
        ip: request.remote_ip,
        token: contribution.payment_token,
        payer_id: params[:PayerID]
      })

      # we must get the deatils after the purchase in order to get the transaction_id
      process_paypal_message purchase.params
      contribution.update_attributes payment_id: purchase.params['transaction_id'] if purchase.params['transaction_id']

      flash[:success] = t('success', scope: SCOPE)
      redirect_to main_app.project_contribution_path(project_id: contribution.project.id, id: contribution.id)
    rescue Exception => e
      Rails.logger.info "-----> #{e.inspect}"
      flash[:failure] = t('paypal_error', scope: SCOPE)
      return redirect_to main_app.new_project_contribution_path(contribution.project)
    end
  end

  def cancel
    flash[:failure] = t('paypal_cancel', scope: SCOPE)
    redirect_to main_app.new_project_contribution_path(contribution.project)
  end

  def contribution
    @contribution ||= if params['id']
                  PaymentEngines.find_payment(id: params['id'])
                elsif params['txn_id']
                  PaymentEngines.find_payment(payment_id: params['txn_id']) || (params['parent_txn_id'] && PaymentEngines.find_payment(payment_id: params['parent_txn_id']))
                end
  end

  def process_paypal_message(data)
    extra_data = (data['charset'] ? JSON.parse(data.to_json.force_encoding(data['charset']).encode('utf-8')) : data)
    PaymentEngines.create_payment_notification contribution_id: contribution.id, extra_data: extra_data

    if data["checkout_status"] == 'PaymentActionCompleted'
      contribution.confirm!
    elsif data["payment_status"]
      case data["payment_status"].downcase
      when 'completed'
        contribution.confirm!
      when 'refunded'
        contribution.refund!
      when 'canceled_reversal'
        contribution.cancel!
      when 'expired', 'denied'
        contribution.pendent!
      else
        contribution.waiting! if contribution.pending?
      end
    end
  end

  def gateway
    @gateway ||= CatarsePaypalExpress::Gateway.instance
  end

  protected

  def notification
    @notification ||= Paypal::Notification.new(request.raw_post)
  end
end
