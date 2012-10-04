require 'spec_helper'

describe CatarsePaypalExpress::Processors::Paypal do
  context "process paypal details_for response" do
    let(:backer) { Factory(:backer, confirmed: false) }

    it "should create a new payment_notifications for backer" do
      backer.payment_notifications.should be_empty
      subject.process!(backer, paypal_details_response)
      backer.payment_notifications.should_not be_empty
    end

    it "should fill extra_data with all response data" do
      subject.process!(backer, paypal_details_response)
      backer.payment_notifications.first.extra_data.should == paypal_details_response
    end

    it "should confirm backer when checkout status is completed" do
      subject.process!(backer, paypal_details_response)
      backer.confirmed.should be_true
    end

    it "should not confirm when checkout status is not completed" do
      subject.process!(backer, paypal_details_response.merge!({"checkout_status" => "just_another_status"}) )
      backer.confirmed.should be_false
    end
  end
end
