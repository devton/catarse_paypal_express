require 'spec_helper'

describe CatarsePaypalExpress::Payment::PaypalExpressController do
  before do
    Configuration.create!(name: "paypal_username", value: "usertest_api1.teste.com")
    Configuration.create!(name: "paypal_password", value: "HVN4PQBGZMHKFVGW")
    Configuration.create!(name: "paypal_signature", value: "AeL-u-Ox.N6Jennvu1G3BcdiTJxQAWdQcjdpLTB9ZaP0-Xuf-U0EQtnS")
    ActiveMerchant::Billing::PaypalExpressGateway.any_instance.stub(:details_for).and_return({})
  end

  context 'when receive a notification' do
    it 'and not found the backer, should return 404' do
      post :notifications, { id: 1, use_route: 'catarse_paypal_express'}
      response.status.should == 404
    end

    it 'and the transaction ID not match, should return 404' do
      backer = Factory(:backer, payment_id: '1234')
      post :notifications, { id: backer.id, txn_id: 123, use_route: 'catarse_paypal_express' }
      response.status.should == 404
    end

    it 'and the transaction ID match, should update the payment status if successful' do
      success_payment_response = mock()
      success_payment_response.stubs(:params).returns({ 'transaction_id' => '1234' })
      success_payment_response.stubs(:success?).returns(true)
      ActiveMerchant::Billing::PaypalExpressGateway.any_instance.stub(:details_for).and_return(success_payment_response)
      backer = Factory(:backer, payment_id: '1234', confirmed: false)

      post :notifications, { id: backer.id, txn_id: 1234, use_route: 'catarse_paypal_express' }

      backer.reload
      response.status.should == 200
      backer.confirmed.should be_true
    end
  end
end
