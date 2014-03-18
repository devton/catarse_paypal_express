begin
  PaymentEngines.register(CatarsePaypalExpress::PaymentEngine.new)
rescue Exception => e
  puts "Error while registering payment engine: #{e}"
end
