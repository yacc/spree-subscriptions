require File.dirname(__FILE__) + '/../spec_helper'

describe SubscriptionManager do
  fixtures :gateways

  def setup
    Gateway.update_all(:active => false)
    @gateway = gateways(:authorize_net_cim_test)
    @gateway.update_attribute(:active, true)
  end
  
  context "with a subscribable item " do
    before (:each) do
      Subscription.delete_all
    end

    context "with valid credit card" do

      it "should create a subscription with a CIM" do
	ActiveMerchant::Billing::AuthorizeNetCimGateway.force_failure = false
	create_subscription_new_order_with_valid_credit_card	
	Subscription.count().should == 1
	Subscription.find(:all, :conditions => {:state => 'active'}).size.should == 1	
      end
      
    end
    
    context "with expired credit card" do

      it "should also create a subscription with a CIM" do
	ActiveMerchant::Billing::AuthorizeNetCimGateway.force_failure = true
	assert_raise(Spree::GatewayError) { create_subscription_new_order_with_expired_credit_card }
	Subscription.count().should == 0	  
	Subscription.find(:all, :conditions => {:state => 'active'}).size.should == 0	
      end
      
    end

  end
end  


