require 'spec_helper'

describe CatarsePaypalExpress::ContributionActions do
  let(:contribution_actions) { CatarsePaypalExpress::ContributionActions.new(contribution) }
  let(:gateway) { double('gateway') }
  let(:contribution) {
    double(:contribution, {id: 1, payment_id: '123a'})
  }
  let(:refund_return) { double }

  before do
    CatarsePaypalExpress::Gateway.stub(:instance).and_return(gateway)
  end

  describe '#refund' do
    subject do
      contribution_actions.refund
    end

    before do
      contribution_actions.should_receive(:gateway).and_call_original
      gateway.should_receive(:refund).with(nil, contribution.payment_id).and_return(refund_return)
    end

    context "success refund" do
      before do
        refund_return.stub(:success?).and_return(true)
      end

      it { should be_true }
    end

    context "failed refund" do
      before do
        refund_return.stub(:success?).and_return(false)
      end

      it { should be_false }
    end
  end
end
