# encoding: utf-8

require 'spec_helper'

describe CatarsePaypalExpress::Payment::PaypalExpressController do
  before do
    Configuration.create!(name: "paypal_username", value: "usertest_api1.teste.com")
    Configuration.create!(name: "paypal_password", value: "HVN4PQBGZMHKFVGW")
    Configuration.create!(name: "paypal_signature", value: "AeL-u-Ox.N6Jennvu1G3BcdiTJxQAWdQcjdpLTB9ZaP0-Xuf-U0EQtnS")
    ActiveMerchant::Billing::PaypalExpressGateway.any_instance.stub(:details_for).and_return({})
    Airbrake.stub(:notify).and_return({})
  end

  subject{ response }

  let(:current_user) { Factory(:user) }

  describe "POST ipn" do
    let(:ipn_data){ {"mc_gross"=>"50.00", "protection_eligibility"=>"Eligible", "address_status"=>"unconfirmed", "payer_id"=>"S7Q8X88KMGX5S", "tax"=>"0.00", "address_street"=>"Rua Tatui, 40 ap 81\r\nJardins", "payment_date"=>"09:03:01 Nov 05, 2012 PST", "payment_status"=>"Completed", "charset"=>"windows-1252", "address_zip"=>"01409-010", "first_name"=>"Paula", "mc_fee"=>"3.30", "address_country_code"=>"BR", "address_name"=>"Paula Rizzo", "notify_version"=>"3.7", "custom"=>"", "payer_status"=>"verified", "address_country"=>"Brazil", "address_city"=>"Sao Paulo", "quantity"=>"1", "verify_sign"=>"ALBe4QrXe2sJhpq1rIN8JxSbK4RZA.Kfc5JlI9Jk4N1VQVTH5hPYOi2S", "payer_email"=>"paula.rizzo@gmail.com", "txn_id"=>"3R811766V4891372K", "payment_type"=>"instant", "last_name"=>"Rizzo", "address_state"=>"SP", "receiver_email"=>"financeiro@catarse.me", "payment_fee"=>"", "receiver_id"=>"BVUB4EVC7YCWL", "txn_type"=>"express_checkout", "item_name"=>"Back project", "mc_currency"=>"BRL", "item_number"=>"", "residence_country"=>"BR", "handling_amount"=>"0.00", "transaction_subject"=>"Back project", "payment_gross"=>"", "shipping"=>"0.00", "ipn_track_id"=>"5865649c8c27"} }
    let(:backer){ Factory(:backer, :payment_id => ipn_data['txn_id'] ) }
    before do
      backer
      post :ipn, ipn_data.merge({ use_route: 'catarse_paypal_express' })
      backer.reload
    end

    it "should update backer's payment_service_fee" do
      backer.payment_service_fee.to_f.should == ipn_data['mc_fee'].to_f
    end

    it "should update backer's payer_email" do
      backer.payer_email.should == ipn_data['payer_email']
    end

    it "should create PaymentNotification for the backer" do
      backer.payment_notifications.first.extra_data['txn_id'].should == ipn_data['txn_id']
    end

    its(:status){ should == 200 }
  
  end
  describe "POST notification" do
    context 'when receive a notification' do
      it 'and not found the backer, should return 404' do
        post :notifications, { id: 1, use_route: 'catarse_paypal_express'}
        response.status.should eq(404)
      end

      it 'and the transaction ID not match, should return 404' do
        backer = Factory(:backer, payment_id: '1234')
        post :notifications, { id: backer.id, txn_id: 123, use_route: 'catarse_paypal_express' }
        response.status.should eq(404)
      end

      it 'should create a payment_notification' do
        success_payment_response = mock()
        success_payment_response.stubs(:params).returns({ 'transaction_id' => '1234', "checkout_status" => "PaymentActionCompleted" })
        success_payment_response.stubs(:success?).returns(true)
        ActiveMerchant::Billing::PaypalExpressGateway.any_instance.stub(:details_for).and_return(success_payment_response)

        backer = Factory(:backer, payment_id: '1234')
        backer.payment_notifications.should be_empty

        post :notifications, { id: backer.id, txn_id: 1234 , use_route: 'catarse_paypal_express' }
        backer.reload

        backer.payment_notifications.should_not be_empty
      end

      it 'and the transaction ID match, should update the payment status if successful' do
        success_payment_response = mock()
        success_payment_response.stubs(:params).returns({ 'transaction_id' => '1234', "checkout_status" => "PaymentActionCompleted" })
        success_payment_response.stubs(:success?).returns(true)
        ActiveMerchant::Billing::PaypalExpressGateway.any_instance.stub(:details_for).and_return(success_payment_response)
        backer = Factory(:backer, payment_id: '1234', confirmed: false)

        post :notifications, { id: backer.id, txn_id: 1234, use_route: 'catarse_paypal_express' }

        backer.reload
        response.status.should eq(200)
        backer.confirmed.should be_true
      end
    end
  end

  describe "GET pay" do
    context 'setup purchase' do
      context 'when have some failures' do
        it 'user not logged in, should redirect' do
          pending 'problems with external application routes'
          #get :pay, {locale: 'en', use_route: 'catarse_paypal_express' }
          #response.status.should eq(302)
        end

        it 'backer not belongs to current_user should 404' do
          backer = Factory(:backer)
          session[:user_id] = current_user.id

          lambda { 
            get :pay, { id: backer.id, locale: 'en', use_route: 'catarse_paypal_express' }
          }.should raise_exception ActiveRecord::RecordNotFound
        end

        it 'raise a exepction because invalid data and should be redirect and set the flash message' do
          ActiveMerchant::Billing::PaypalExpressGateway.any_instance.stub(:setup_purchase).and_raise(StandardError)
          session[:user_id] = current_user.id
          backer = Factory(:backer, user: current_user)

          get :pay, { id: backer.id, locale: 'en', use_route: 'catarse_paypal_express' }
          flash[:failure].should == I18n.t('paypal_error', scope: CatarsePaypalExpress::Payment::PaypalExpressController::SCOPE)
          response.should be_redirect
        end
      end

      context 'when successul' do
        before do
          success_response = mock()
          success_response.stub(:token).and_return('ABCD')
          success_response.stub(:params).and_return({ 'correlation_id' => '123' })
          ActiveMerchant::Billing::PaypalExpressGateway.any_instance.stub(:setup_purchase).and_return(success_response)
        end

        it 'should create a payment_notification' do
          session[:user_id] = current_user.id
          backer = Factory(:backer, user: current_user)

          get :pay, { id: backer.id, locale: 'en', use_route: 'catarse_paypal_express' }
          backer.reload

          backer.payment_notifications.should_not be_empty
        end

        it 'payment method and token should be persisted ' do
          session[:user_id] = current_user.id
          backer = Factory(:backer, user: current_user)

          get :pay, { id: backer.id, locale: 'en', use_route: 'catarse_paypal_express' }
          backer.reload

          backer.payment_method.should == 'PayPal'
          backer.payment_token.should == 'ABCD'

          # The correlation id should not be stored in payment_id, which is only for transaction_id
          backer.payment_id.should be_nil

          response.should be_redirect
        end
      end
    end
  end

  describe "GET cancel" do
    context 'when cancel the paypal purchase' do
      it 'should show for user the flash message' do
        session[:user_id] = current_user.id
        backer = Factory(:backer, user: current_user, payment_token: 'TOKEN')

        get :cancel, { id: backer.id, locale: 'en', use_route: 'catarse_paypal_express' }
        flash[:failure].should == I18n.t('paypal_cancel', scope: CatarsePaypalExpress::Payment::PaypalExpressController::SCOPE)
        response.should be_redirect
      end
    end
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
          session[:user_id] = current_user.id
          backer = Factory(:backer, user: current_user, payment_token: 'TOKEN')
          backer.payment_notifications.should be_empty

          get :success, { id: backer.id, PayerID: '123', locale: 'en', use_route: 'catarse_paypal_express' }
          backer.reload

          backer.payment_notifications.should_not be_empty
          backer.confirmed.should be_true
          backer.payment_id.should == '12345'
          response.should redirect_to("/projects/#{backer.project.id}/backers/#{backer.id}/thank_you")
        end
      end

      context 'when paypal purchase raise a error' do
        before do
          ActiveMerchant::Billing::PaypalExpressGateway.any_instance.stub(:purchase).and_raise(StandardError)
        end

        it 'should be redirect and show a flash message' do
          session[:user_id] = current_user.id
          backer = Factory(:backer, user: current_user)

          get :success, { id: backer.id, PayerID: '123', locale: 'en', use_route: 'catarse_paypal_express' }

          flash[:failure].should == I18n.t('paypal_error', scope: CatarsePaypalExpress::Payment::PaypalExpressController::SCOPE)
          response.should be_redirect
        end
      end
    end
  end

end
