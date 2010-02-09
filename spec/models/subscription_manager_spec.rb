require File.dirname(__FILE__) + '/../spec_helper'

describe SubscriptionManager do
  fixtures :gateways

  def setup
    Gateway.update_all(:active => false)
    @gateway = gateways(:authorize_net_cim_test)
    @gateway.update_attribute(:active, true)
  end
  
  context "with no active transaction" do

    it "should do nothing" do
      @sub = Factory(:subscription,:state => 'expired', :creditcard => @creditcard)
      SubscriptionManager.process.should == {:active => 0, :processed => 0,:reminded => 0, :expired => 0, :error =>0}
    end
  end

  context "with due subscription" do
    
    context "with valid credit card" do
      
      it "should find one active subscription and process one payment" do
	# changing the intervall to create a due subscription
	# @sub = Factory(:subscription,:state => 'active',:interval => 'day', :creditcard => @creditcard)
	create_subscription_new_order_with_valid_credit_card
	Subscription.count().should == 1
	Subscription.find(:all, :conditions => {:state => 'active'}).size.should == 1
	report = SubscriptionManager.process
	report.should == {:active => 1, :processed => 1,:reminded => 0, :expired => 0, :error =>0}
	Order.count.should == 25
      end
    end
    
    context "with expired credit card" do
      
      it "should find one active subscription and process one notice" do
	create_subscription_new_order_with_expired_credit_card 
	ActiveMerchant::Billing::AuthorizeNetCimGateway.force_failure = true
	Subscription.count().should == 1
	Subscription.find(:all, :conditions => {:state => 'active'}).size.should == 1
	report = SubscriptionManager.process 
	report.should == {:active => 1, :processed => 0,:reminded => 1, :expired => 1, :error => 1}
	Order.count.should == 24
      end
    end
    
  end
  
  context "with expired credit cards" do
  end
end

