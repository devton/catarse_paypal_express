require 'catarse_paypal_express/processors'

module CatarsePaypalExpress::Payment
  class PaypalExpressController < ApplicationController
    skip_before_filter :verify_authenticity_token, :only => [:notifications]
    skip_before_filter :detect_locale, :only => [:notifications]
    skip_before_filter :set_locale, :only => [:notifications]

    before_filter :setup_gateway

    SCOPE = "projects.backers.checkout"

    layout :false

    def review

    end

    def ipn
      backer = Backer.where(:txn_id => params['txn_id']).first
      notification = backer.payment_notifications.new({
        extra_data: data
      })
      notification.save!
      return render status: 200, nothing: true
    rescue Exception => e
      ::Airbrake.notify({ :error_class => "Paypal Notification Error", :error_message => "Paypal Notification Error: #{e.inspect}", :parameters => params}) rescue nil
      return render status: 200, nothing: true
    end

    def notifications
      backer = Backer.find params[:id]
      response = @@gateway.details_for(backer.payment_token)
      if response.params['transaction_id'] == params['txn_id']
        build_notification(backer, response.params)
        render status: 200, nothing: true
      else
        render status: 404, nothing: true
      end
    rescue Exception => e
      ::Airbrake.notify({ :error_class => "Paypal Notification Error", :error_message => "Paypal Notification Error: #{e.inspect}", :parameters => params}) rescue nil
      render status: 404, nothing: true
    end

    def pay
      backer = current_user.backs.find params[:id]
      begin
        response = @@gateway.setup_purchase(backer.price_in_cents, {
          ip: request.remote_ip,
          return_url: payment_success_paypal_express_url(id: backer.id),
          cancel_return_url: payment_cancel_paypal_express_url(id: backer.id),
          currency_code: 'BRL',
          description: t('paypal_description', scope: SCOPE, :project_name => backer.project.name, :value => backer.display_value),
          notify_url: payment_notifications_paypal_express_url(id: backer.id)
        })

        backer.update_attribute :payment_method, 'PayPal'
        backer.update_attribute :payment_token, response.token

        build_notification(backer, response.params)

        redirect_to @@gateway.redirect_url_for(response.token)
      rescue Exception => e
        ::Airbrake.notify({ :error_class => "Paypal Error", :error_message => "Paypal Error: #{e.inspect}", :parameters => params}) rescue nil
        Rails.logger.info "-----> #{e.inspect}"
        paypal_flash_error
        return redirect_to main_app.new_project_backer_path(backer.project)
      end
    end

    def success
      backer = current_user.backs.find params[:id]
      begin
        response = @@gateway.purchase(backer.price_in_cents, {
          ip: request.remote_ip,
          token: backer.payment_token,
          payer_id: params[:PayerID]
        })

        # we must get the deatils after the purchase in order to get the transaction_id
        details = @@gateway.details_for(backer.payment_token)

        build_notification(backer, details.params)

        if details.params['transaction_id'] 
          backer.update_attribute :payment_id, details.params['transaction_id']
        end

        session[:thank_you_id] = backer.project.id
        session[:_payment_token] = backer.payment_token

        paypal_flash_success
        redirect_to main_app.thank_you_path
      rescue Exception => e
        ::Airbrake.notify({ :error_class => "Paypal Error", :error_message => "Paypal Error: #{e.message}", :parameters => params}) rescue nil
        Rails.logger.info "-----> #{e.inspect}"
        paypal_flash_error
        return redirect_to main_app.new_project_backer_path(backer.project)
      end
    end

    def cancel
      backer = current_user.backs.find params[:id]
      flash[:failure] = t('paypal_cancel', scope: SCOPE)
      redirect_to main_app.new_project_backer_path(backer.project)
    end

  private

    def build_notification(backer, data)
      processor = CatarsePaypalExpress::Processors::Paypal.new
      processor.process!(backer, data)
    end

    def paypal_flash_error
      flash[:failure] = t('paypal_error', scope: SCOPE)
    end

    def paypal_flash_success
      flash[:success] = t('success', scope: SCOPE)
    end

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
