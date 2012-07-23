require 'spec_helper'

describe CatarsePaypalExpress::Payment::PaypalExpressController do
  context 'when receive a notification' do
    before do
      ActiveMerchant::Billing::PaypalExpressGateway.any_instance.stub(:details_for).and_return({})
    end

    it 'and not found the backer should return 404' do
      post :notifications, { id: 1 }
      response.status.should == 404
    end

    it 'and the transaction ID not match should return 404' do
      backer = Factory(:backer, payment_id: '1234')
      post :notifications, { id: backer.id, txn_id: 123 }
      response.status.should == 404
    end

    it 'and the transaction ID match should update the payment status' do
      pending
    end
  end
end
