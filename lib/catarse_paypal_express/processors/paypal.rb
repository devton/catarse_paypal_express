module CatarsePaypalExpress
  module Processors
    class Paypal

      def process!(backer, data)
        status = data["checkout_status"] || "pending"

        notification = backer.payment_notifications.new({
          extra_data: data
        })

        notification.save!

        if success_payment?(status)
          backer.confirm! 
        elsif data["payment_status"]
          case data["payment_status"].downcase
          when 'refunded'
          backer.refund!
          when 'canceled_reversal'
          backer.cancel!
          when 'expired', 'denied'
          backer.pendent! 
          end
        end
      end

      protected

      def success_payment?(status)
        status == 'PaymentActionCompleted'
      end

    end
  end
end
