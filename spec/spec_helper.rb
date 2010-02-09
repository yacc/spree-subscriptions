unless defined? SPREE_ROOT
  ENV["RAILS_ENV"] = "test"
  case
  when ENV["SPREE_ENV_FILE"]
    require File.dirname(ENV["SPREE_ENV_FILE"]) + "/boot"
  when File.dirname(__FILE__) =~ %r{vendor/SPREE/vendor/extensions}
    require "#{File.expand_path(File.dirname(__FILE__) + "/../../../../../../")}/config/boot"
  else
    require "#{File.expand_path(File.dirname(__FILE__) + "/../../../../")}/config/boot"
  end
end
require "#{SPREE_ROOT}/test/test_helper"
require "#{SPREE_ROOT}/spec/spec_helper"

Spec::Runner.configure do |config|
  config.use_transactional_fixtures = true
  config.fixture_path = "#{SPREE_ROOT}/test/fixtures"
end


def create_subscription_complete_order
  @zone = Zone.global
  @order = Factory(:order)
  @interval_option = Factory(:option_value, :name => '1', :presentation => 'One',
			     :option_type => Factory(:option_type, :name => 'subscription-interval') )
  @duration_option = Factory(:option_value, :name => 'day', :presentation => 'One',
			     :option_type => Factory(:option_type, :name => 'subscription-duration') )
  @variant = Factory(:variant,:price => 5.00, :subscribable => true,
		     :option_values => [@interval_option,@duration_option])
  
  Factory(:line_item, :variant => @variant, :order => @order, :quantity => 1, :price => 5.00)

  @shipping_method = Factory(:shipping_method)

  @checkout = @order.checkout
  @checkout.ship_address = Factory(:address)
  @checkout.shipping_method = @shipping_method
  @checkout.save

  
  @shipment = @order.shipment

  @checkout.bill_address = Factory(:address)

  unless @zone.include?(@order.shipment.address)
    ZoneMember.create(:zone => Zone.global, :zoneable => @checkout.ship_address.country)
    @zone.reload
  end

  @checkout.save
  @shipment.save
  @order.save
  @order.reload
  @order.save
  @order
end

def create_subscription_new_order_with_valid_credit_card
  create_subscription_complete_order
  @creditcard = Factory(:creditcard, :verification_value => '123', :number => '4242424242424242',
			  :month => 9, :year => Time.now.year + 1, :first_name => 'John', :last_name => 'Doe')
  @checkout.creditcard = @creditcard
  @checkout.state = "complete"
  @checkout.save
end
  
def create_subscription_new_order_with_expired_credit_card
  #first order goes throught, but then the cc expires
  create_subscription_complete_order
  @creditcard = Factory(:creditcard, :verification_value => '123', :number => '4242424242424242',
			  :month => 9, :year => Time.now.year, :first_name => 'John', :last_name => 'Doe')
  @checkout.creditcard = @creditcard
  @checkout.state = "complete"
  @checkout.save
  @creditcard.update_attribute(:year, Time.now.year-3)
end

