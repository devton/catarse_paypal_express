# CatarsePaypalExpress

Catarse paypal express integration with [Catarse](http://github.com/danielweinmann/catarse) crowdfunding platform

## Installation

Add this lines to your Catarse application's Gemfile:

    gem 'catarse_paypal_express'

And then execute:

    $ bundle

## Usage

Configure the routes for your Catarse application. Add the following lines in the routes file (config/routes.rb):

    mount CatarsePaypalExpress::Engine => "/", :as => "catarse_paypal_express"

### Configurations

Create this configurations into Catarse database:

    paypal_username, paypal_password and paypal_signature

In Rails console, run this:

    Configuration.create!(name: "paypal_username", value: "USERNAME")
    Configuration.create!(name: "paypal_password", value: "PASSWORD")
    Configuration.create!(name: "paypal_signature", value: "SIGNATURE")

## Development environment setup

Clone the repository:

    $ git clone git://github.com/devton/catarse_paypal_express.git

Add the catarse code into test/dummy:

    $ git submodule add git://github.com/danielweinmann/catarse.git test/dummy

Copy the Catarse's gems to Gemfile:

    $ cat test/dummy/Gemfile >> Gemfile

And then execute:

    $ bundle

## Troubleshooting in development environment

remove the admin folder from test/dummy application to prevent a weird active admin bug:

  $ rm -rf test/dummy/app/admin

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request


This project rocks and uses MIT-LICENSE.
