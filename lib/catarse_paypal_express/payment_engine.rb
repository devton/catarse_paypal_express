begin
  module CatarsePaypalExpress
    class PaymentEngine < PaymentEngines::Interface

      def name
        'PayPal'
      end

      def review_path contribution
        CatarsePaypalExpress::Engine.routes.url_helpers.review_paypal_express_path(contribution)
      end

      def can_do_refund?
        true
      end

      def direct_refund contribution
        CatarsePaypalExpress::ContributionActions.new(contribution).refund
      end

      def locale
        'en'
      end

    end
  end
rescue Exception => e
  puts "Error while use payment engine interface: #{e}"
end
