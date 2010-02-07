# Uncomment this if you reference any of your controllers in activate
# require_dependency 'application'

class SubscriptionsExtension < Spree::Extension
  version "0.8.5"
  description "Subscription extension for Spree (tested with Authorized.net CIM"
  url "http://yourwebsite.com/subscription"
  
  def activate
    
    Payment.class_eval do
      belongs_to :subscription

      private
      def check_payments_with_subscription                            
	return unless subscription_id.nil? 
	check_payments_without_subscription
      end
      def amount_is_valid_for_outstanding_balance_or_credit_with_subscription
	return if order.nil? 
	amount_is_valid_for_outstanding_balance_or_credit_without_subscription
      end
      alias_method_chain :check_payments, :subscription
      alias_method_chain :amount_is_valid_for_outstanding_balance_or_credit, :subscription
    end

    Admin::PaymentsController.class_eval do
      belongs_to :subscription
      before_filter :load_data
      
      private
      def load_data_with_subscription
        if params.key? "subscription_id"
          @subscription = Subscription.find(params[:subscription_id])
        end
	load_data_without_subscription
      end
      alias_method_chain :load_data, :subscription
    end

    Variant.additional_fields += [ {:name => 'Subscribable', :only => [:variant], :use => 'select',
	:value => lambda { |controller, field| [["False", false], ["True", true]]  } } ]

    Variant.class_eval do
      has_many :subscriptions
    end
    
    User.class_eval do
      has_many :subscriptions
    end	
    
    Creditcard.class_eval	do
      has_many :subscriptions
    end
    
    LineItem.class_eval do
      def subscribable?
	if self.variant.product.respond_to?(:subscribable?) 
	  self.variant.is_master? && self.variant.product.subscribable? 
	elsif self.variant.respond_to?(:subscribable?)
	  !self.variant.is_master? && self.variant.subscribable?
	end
      end      
    end
    
    
    Checkout.class_eval do
      before_save :subscriptions_check
      
      private 
      
      def subscriptions_check
	return unless ( complete? && creditcard ) 
	
	# payment_profile_key = nil
	
	order.line_items.each do |line_item|
	  if line_item.subscribable?	    
	    #TODO: test that GW supports CIM
	    
	    #get customer profile information (saved with CC if GW supports it)
	    payment_profile_key = creditcard.gateway_customer_profile_id
	    gate_opts = creditcard.gateway_options
	    
	    #get subscription info
	    interval = line_item.variant.option_values.detect { |ov| ov.option_type.name == "subscription-interval"}.name
	    duration = line_item.variant.option_values.detect { |ov| ov.option_type.name == "subscription-duration"}.name

	    #create subscription
	    subscription = Subscription.create(:interval => interval, 
					       :duration => duration, 
					       :user => order.user, 
					       :variant => line_item.variant, 
					       :creditcard => creditcard,
					       :payment_profile_key => payment_profile_key)
	    
	    #add dummy first payment (real payment was taken by normal checkout)
	    #TODO: do I need to create a fake payment, now that I have a handle on the CC payment?
	    payment = CreditcardPayment.create(:subscription => subscription, :amount => line_item.variant.price,
					       :type => "CreditcardPayment", :creditcard => creditcard)
	    payment.creditcard_txns == creditcard.creditcard_txns
	    subscription.payments << payment
	    subscription.save
	  end
	end
      end
    end
    
    Gateway::Bogus.class_eval do
      def store(creditcard, options = {})      
        if Gateway::Bogus::VALID_CCS.include? creditcard.number 
          ActiveMerchant::Billing::Response.new(true, "Bogus Gateway: Forced success", {}, :test => true, :customerCode => '12345')
        else
          ActiveMerchant::Billing::Response.new(false, "Bogus Gateway: Forced failure", {:message => 'Bogus Gateway: Forced failure'}, :test => true)
        end      
      end
    end
    
  end

end

