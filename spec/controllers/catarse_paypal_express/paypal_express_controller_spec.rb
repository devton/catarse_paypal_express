# encoding: utf-8

require 'spec_helper'

describe CatarsePaypalExpress::PaypalExpressController do
  SCOPE = CatarsePaypalExpress::PaypalExpressController::SCOPE
  before do
    PaymentEngines.stub(:find_payment).and_return(backer)
    PaymentEngines.stub(:create_payment_notification)
    controller.stub(:main_app).and_return(main_app)
    controller.stub(:current_user).and_return(current_user)
    controller.stub(:gateway).and_return(gateway)
  end

  subject{ response }
  let(:gateway){ double('gateway') }
  let(:main_app){ double('main_app') }
  let(:current_user) { double('current_user') }
  let(:project){ double('project', id: 1, name: 'test project') }
  let(:backer){ double('backer', {
    id: 1, 
    key: 'backer key', 
    payment_id: 'payment id', 
    project: project, 
    pending?: false, 
    value: 10, 
    display_value: 'R$ 10,00',
    price_in_cents: 1000,
    user: current_user, 
    payer_name: 'foo',
    payer_email: 'foo@bar.com',
    address_street: 'test',
    address_number: '123',
    address_complement: '123',
    address_neighbourhood: '123',
    address_city: '123',
    address_state: '123',
    address_zip_code: '123',
    address_phone_number: '123'
  }) }


  describe "POST ipn" do
    let(:ipn_data){ {"mc_gross"=>"50.00", "protection_eligibility"=>"Eligible", "address_status"=>"unconfirmed", "payer_id"=>"S7Q8X88KMGX5S", "tax"=>"0.00", "address_street"=>"Rua Tatui, 40 ap 81\r\nJardins", "payment_date"=>"09:03:01 Nov 05, 2012 PST", "payment_status"=>"Completed", "charset"=>"windows-1252", "address_zip"=>"01409-010", "first_name"=>"Paula", "mc_fee"=>"3.30", "address_country_code"=>"BR", "address_name"=>"Paula Rizzo", "notify_version"=>"3.7", "custom"=>"", "payer_status"=>"verified", "address_country"=>"Brazil", "address_city"=>"Sao Paulo", "quantity"=>"1", "verify_sign"=>"ALBe4QrXe2sJhpq1rIN8JxSbK4RZA.Kfc5JlI9Jk4N1VQVTH5hPYOi2S", "payer_email"=>"paula.rizzo@gmail.com", "txn_id"=>"3R811766V4891372K", "payment_type"=>"instant", "last_name"=>"Rizzo", "address_state"=>"SP", "receiver_email"=>"financeiro@catarse.me", "payment_fee"=>"", "receiver_id"=>"BVUB4EVC7YCWL", "txn_type"=>"express_checkout", "item_name"=>"Back project", "mc_currency"=>"BRL", "item_number"=>"", "residence_country"=>"BR", "handling_amount"=>"0.00", "transaction_subject"=>"Back project", "payment_gross"=>"", "shipping"=>"0.00", "ipn_track_id"=>"5865649c8c27"} }

    let(:backer){ double(:backer, :payment_id => ipn_data['txn_id'] ) }

    before do
      params = ipn_data.merge({ use_route: 'catarse_paypal_express' })
      backer.should_receive(:update_attributes).with({
        payment_service_fee: ipn_data['mc_fee'], 
        payer_email: ipn_data['payer_email']
      })
      controller.should_receive(:process_paypal_message).with(ipn_data.merge({
        "controller"=>"catarse_paypal_express/paypal_express", 
        "action"=>"ipn"
      }))
      post :ipn, params
    end

    its(:status){ should == 200 }
    its(:body){ should == ' ' }
  end

  describe "GET pay" do
    before do
      set_paypal_response
      get :pay, { id: backer.id, locale: 'en', use_route: 'catarse_paypal_express' }
    end


    context 'when response raises a exception' do
      let(:set_paypal_response) do 
        main_app.should_receive(:new_project_backer_path).with(backer.project).and_return('error url')
        gateway.should_receive(:setup_purchase).and_raise(StandardError)
      end
      it 'should assign flash error' do
        controller.flash[:failure].should == I18n.t('paypal_error', scope: SCOPE)
      end
      it{ should redirect_to 'error url' }
    end

    context 'when successul' do
      let(:set_paypal_response) do 
        success_response = double('success_response', {
          token: 'ABCD',
          params: { 'correlation_id' => '123' }
        })
        gateway.should_receive(:setup_purchase).with(
          backer.price_in_cents, 
          {
            ip: request.remote_ip,
            return_url: 'http://test.host/catarse_paypal_express/payment/paypal_express/1/success',
            cancel_return_url: 'http://test.host/catarse_paypal_express/payment/paypal_express/1/cancel',
            currency_code: 'BRL',
            description: I18n.t('paypal_description', scope: SCOPE, :project_name => backer.project.name, :value => backer.display_value),
            notify_url: 'http://test.host/catarse_paypal_express/payment/paypal_express/ipn'
          }
        ).and_return(success_response)
        backer.should_receive(:update_attributes).with({
          payment_method: "PayPal", 
          payment_token: "ABCD"
        })
        gateway.should_receive(:redirect_url_for).with('ABCD').and_return('success url')
      end
      it{ should redirect_to 'success url' }
    end
  end

  describe "GET cancel" do
    before do
      main_app.should_receive(:new_project_backer_path).with(backer.project).and_return('new backer url')
      get :cancel, { id: backer.id, locale: 'en', use_route: 'catarse_paypal_express' }
    end
    it 'should show for user the flash message' do
      controller.flash[:failure].should == I18n.t('paypal_cancel', scope: SCOPE)
    end
    it{ should redirect_to 'new backer url' }
  end

  describe "GET success" do
    let(:success_details){ {'transaction_id' => nil, "checkout_status" => "PaymentActionCompleted"} }
    let(:fake_success_details) do
      fake_success_details = mock()
      fake_success_details.stub(:params).and_return(success_details)
      fake_success_details
    end

    context 'paypal returning to success route' do

      context 'when paypal purchase is ok' do
        before(:each) do
          ActiveMerchant::Billing::PaypalExpressGateway.any_instance.stub(:details_for) do
            # If we call the details_for before purchase the transaction_id will not be present
            success_details.delete('transaction_id') unless success_details['transaction_id'] == '12345'
            fake_success_details
          end
          fake_success_purchase = mock()
          fake_success_purchase.stub(:success?).and_return(true)
          ActiveMerchant::Billing::PaypalExpressGateway.any_instance.stub(:purchase) do
            # only after the purchase command the transactio_id is set in the details_for
            success_details['transaction_id'] = '12345' if success_details.include?('transaction_id')
            fake_success_purchase
          end
        end

        it 'should update the backer and redirect to thank_you' do
          get :success, { id: backer.id, PayerID: '123', locale: 'en', use_route: 'catarse_paypal_express' }
          backer.payment_notifications.should_not be_empty
          backer.confirmed.should be_true
          backer.payment_id.should == '12345'
          response.should redirect_to("/projects/#{backer.project.id}/backers/#{backer.id}")
        end
      end

      context 'when paypal purchase raise a error' do
        before do
          ActiveMerchant::Billing::PaypalExpressGateway.any_instance.stub(:purchase).and_raise(StandardError)
        end

        it 'should be redirect and show a flash message' do
          get :success, { id: backer.id, PayerID: '123', locale: 'en', use_route: 'catarse_paypal_express' }

          flash[:failure].should == I18n.t('paypal_error', scope: CatarsePaypalExpress::Payment::PaypalExpressController::SCOPE)
          response.should be_redirect
        end
      end
    end
  end

end
