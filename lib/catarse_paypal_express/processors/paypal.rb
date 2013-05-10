module CatarsePaypalExpress
  module Processors
    class Paypal

      def process!(backer, data)
        status = data["checkout_status"] || "pending"

        notification = backer.payment_notifications.new({
          extra_data: data
        })

        notification.save!

        backer.confirm! if success_payment?(status)
        backer.refund! if data["payment_status"].downcase == 'refunded'
        backer.cancel! if data["payment_status"].downcase == 'canceled_reversal'
        backer.pendent! if data["payment_status"].downcase == 'expired' || data["payment_status"].downcase == 'denied'
      end

      protected

      def success_payment?(status)
        status == 'PaymentActionCompleted'
      end

    end
  end
end
