# This file is copied to spec/ when you run 'rails generate rspec:install'
ENV["RAILS_ENV"] ||= 'test'
require File.expand_path("../../test/dummy/config/environment", __FILE__)
require 'rspec/rails'
require 'rspec/autorun'

ENGINE_RAILS_ROOT=File.join(File.dirname(__FILE__), '../')

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
Dir[File.join(ENGINE_RAILS_ROOT, 'spec/support/**/*.rb')].each {|f| require f }


RSpec.configure do |config|
  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  config.fixture_path = "#{ENGINE_RAILS_ROOT}/spec/fixtures"

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, remove the following line or assign false
  # instead of true.
  config.use_transactional_fixtures = true

  # If true, the base class of anonymous controllers will be inferred
  # automatically. This will be the default behavior in future versions of
  # rspec-rails.
  config.infer_base_class_for_anonymous_controllers = false

  # Include Engine routes (needed for Controller specs)
  config.include CatarsePaypalExpress::Engine.routes.url_helpers

  config.before(:each) do
    PaymentEngines.stub(:configuration).and_return({})
  end
end

def fixture_file(filename)
  return nil if filename.nil?
  file_path = File.expand_path(File.dirname(__FILE__) + '/fixtures/' + filename)
  File.read(file_path)
end

def paypal_setup_purchase_success_response
  { "timestamp"=>"2012-07-23T00:24:21Z", "ack"=>"Success", "correlation_id"=>"dcb8596be51cd", "version"=>"62.0", "build"=>"3332236",
    "token"=>"EC-49X25168KR2556548", "Timestamp"=>"2012-07-23T00:24:21Z", "Ack"=>"Success", "CorrelationID"=>"dcb8596be51cd", 
    "Version"=>"62.0", "Build"=>"3332236", "Token"=>"EC-49X25168KR2556548" }
end

def paypal_details_response
  {
    "transaction_id" => "1234",
    "checkout_status" => "PaymentActionCompleted",
    "payment_status" => 'Completed'
  }
end

def paypal_details_response_refunded
  {
    "transaction_id" => "1234",
    "checkout_status" => "PaymentActionCompleted",
    "payment_status" => 'Refunded'
  }
end
