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
    pending?: true, 
    value: 10, 
    display_value: 'R$ 10,00',
    price_in_cents: 1000,
    user: current_user, 
    payer_name: 'foo',
    payer_email: 'foo@bar.com',
    payment_token: 'token',
    address_street: 'test',
    address_number: '123',
    address_complement: '123',
    address_neighbourhood: '123',
    address_city: '123',
    address_state: '123',
    address_zip_code: '123',
    address_phone_number: '123'
  }) }

  describe "GET review" do
    before do
      get :review, id: backer.id, use_route: 'catarse_paypal_express' 
    end
    it{ should render_template(:review) }
  end

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
    let(:success_details){ double('success_details', params: {'transaction_id' => '12345', "checkout_status" => "PaymentActionCompleted"}) }
    let(:params){{ id: backer.id, PayerID: '123', locale: 'en', use_route: 'catarse_paypal_express' }}

    before do
      gateway.should_receive(:purchase).with(backer.price_in_cents, {
        ip: request.remote_ip,
        token: backer.payment_token,
        payer_id: params[:PayerID]
      }).and_return(success_details)
      controller.should_receive(:process_paypal_message).with(success_details.params)
      backer.should_receive(:update_attributes).with(payment_id: '12345')
      set_redirect_expectations
      get :success, params
    end

    context "when purchase is successful" do
      let(:set_redirect_expectations) do
        main_app.
          should_receive(:project_backer_path).
          with(project_id: backer.project.id, id: backer.id).
          and_return('back url')
      end
      it{ should redirect_to 'back url' }
      it 'should assign flash message' do
        controller.flash[:success].should == I18n.t('success', scope: SCOPE)
      end
    end

    context 'when paypal purchase raises some error' do
      let(:set_redirect_expectations) do
        main_app.
          should_receive(:project_backer_path).
          with(project_id: backer.project.id, id: backer.id).
          and_raise('error')
        main_app.
          should_receive(:new_project_backer_path).
          with(backer.project).
          and_return('new back url')
      end
      it 'should assign flash error' do
        controller.flash[:failure].should == I18n.t('paypal_error', scope: SCOPE)
      end
      it{ should redirect_to 'new back url' }
    end
  end

  describe "#gateway" do
    before do
      controller.stub(:gateway).and_call_original
      PaymentEngines.stub(:configuration).and_return(paypal_config)
    end
    subject{ controller.gateway }
    context "when we have the paypal configuration" do
      let(:paypal_config) do
        { paypal_username: 'username', paypal_password: 'pass', paypal_signature: 'signature' }
      end
      before do
        ActiveMerchant::Billing::PaypalExpressGateway.should_receive(:new).with({
          login: PaymentEngines.configuration[:paypal_username],
          password: PaymentEngines.configuration[:paypal_password],
          signature: PaymentEngines.configuration[:paypal_signature]
        }).and_return('gateway instance')
      end
      it{ should == 'gateway instance' }
    end

    context "when we do not have the paypal configuration" do
      let(:paypal_config){ {} }
      before do
        ActiveMerchant::Billing::PaypalExpressGateway.should_not_receive(:new)
      end
      it{ should be_nil }
    end
  end

  describe "#backer" do
    subject{ controller.backer }
    context "when we have an id" do
      before do
        controller.stub(:params).and_return({'id' => '1'})
        PaymentEngines.should_receive(:find_payment).with(id: '1').and_return(backer)
      end
      it{ should == backer }
    end

    context "when we have an txn_id" do
      before do
        controller.stub(:params).and_return({'txn_id' => '1'})
        PaymentEngines.should_receive(:find_payment).with(payment_id: '1').and_return(backer)
      end
      it{ should == backer }
    end
  end

  describe "#process_paypal_message" do
    subject{ controller.process_paypal_message data }
    let(:data){ {'test_data' => true} }
    before do
      PaymentEngines.should_receive(:create_payment_notification).with(backer_id: backer.id, extra_data: data)
    end
    
    context "when data['checkout_status'] == 'PaymentActionCompleted'" do
      let(:data){ {'checkout_status' => 'PaymentActionCompleted'} }
      before do
        backer.should_receive(:confirm!)
      end
      it("should call confirm"){ subject }
    end

    context "some real data with revert op" do
      let(:data){ { "mc_gross" => "-150.00","protection_eligibility" => "Eligible","payer_id" => "4DK6S6Q75Z5YS","address_street" => "AV. SAO CARLOS, 2205 - conj 501/502 Centro","payment_date" => "09:55:14 Jun 26, 2013 PDT","payment_status" => "Refunded","charset" => "utf-8","address_zip" => "13560-900","first_name" => "Marcius","mc_fee" => "-8.70","address_country_code" => "BR","address_name" => "Marcius Milori","notify_version" => "3.7","reason_code" => "refund","custom" => "","address_country" => "Brazil","address_city" => "São Carlos","verify_sign" => "AbedXpvDaliC7hltYoQrebkEQft7A.y6bRnDvjPIIB1Mct8-aDGcHkcV","payer_email" => "milorimarcius@gmail.com","parent_txn_id" => "78T862320S496750Y","txn_id" => "9RP43514H84299332","payment_type" => "instant","last_name" => "Milori","address_state" => "São Paulo","receiver_email" => "financeiro@catarse.me","payment_fee" => "","receiver_id" => "BVUB4EVC7YCWL","item_name" => "Apoio para o projeto A Caça (La Chasse) no valor de R$ 150","mc_currency" => "BRL","item_number" => "","residence_country" => "BR","handling_amount" => "0.00","transaction_subject" => "Apoio para o projeto A Caça (La Chasse) no valor de R$ 150","payment_gross" => "","shipping" => "0.00","ipn_track_id" => "18c487e6abca4" } }
      before do
        backer.should_receive(:refund!)
      end
      it("should call refund"){ subject }
    end

    context "when it's a refund message" do
      let(:data){ {'payment_status' => 'refunded'} }
      before do
        backer.should_receive(:refund!)
      end
      it("should call refund"){ subject }
    end

    context "when it's a completed message" do
      let(:data){ {'payment_status' => 'Completed'} }
      before do
        backer.should_receive(:confirm!)
      end
      it("should call confirm"){ subject }
    end

    context "when it's a cancelation message" do
      let(:data){ {'payment_status' => 'canceled_reversal'} }
      before do
        backer.should_receive(:cancel!)
      end
      it("should call cancel"){ subject }
    end

    context "when it's a payment expired message" do
      let(:data){ {'payment_status' => 'expired'} }
      before do
        backer.should_receive(:pendent!)
      end
      it("should call pendent"){ subject }
    end

    context "all other values of payment_status" do
      let(:data){ {'payment_status' => 'other'} }
      before do
        backer.should_receive(:waiting!)
      end
      it("should call waiting"){ subject }
    end
  end
end
