include ActionView::Helpers::DateHelper

class SubscriptionManager
  
  def SubscriptionManager.process()
    @report = {:active => 0, :processed => 0,:reminded => 0, :expired => 0, :error => 0}
    subscriptions = Subscription.find(:all, :conditions => {:state => 'active'})
    subscriptions.empty? ? (return @report) : (@report[:active] = subscriptions.size)
    check_for_renewals(subscriptions)
    check_for_creditcard_expiry(subscriptions)
    @report
  end
  
  def SubscriptionManager.check_for_renewals(subscriptions)
    subscriptions.each do |sub|
      next unless sub.due_on.to_time <= Time.now()
      begin
	amount = sub.variant.price * 100
	#subscription due for renewal, we create a new order just for this period
	sub_order = Order.new(:user_id => sub.user_id)
	sub_order.line_items = sub.variant.line_items
	sub_order.save!
	# let's process the order, we do that by forcing the checkout process manually
	# all the information necessary to submit a payment is stored un the customer profile
	sub_order.checkout.creditcard = sub.creditcard
	sub_order.checkout.state = 'address'
	3.times { sub_order.checkout.next! }
	sub_order.pay! unless Spree::Config[:auto_capture]
	@report[:processed] += 1
	# TODO: yacin: SubscriptionMailer.deliver_payment_receipt(sub)
	# Missing template subscription_mailer/payment_receipt.erb
      rescue Spree::GatewayError => ge
	# puts "#{ge}:\n#{ge.backtrace.join("\n")}"
	@report[:error] += 1
      end
    end
  end
  
  def SubscriptionManager.check_for_creditcard_expiry(subscriptions)
    subscriptions.each do |sub|
      cc_exp_date = Time.parse("#{sub.creditcard.month}/#{sub.creditcard.year}").end_of_month
      # cc_exp_date = "#{sub.creditcard.month}/#{cc_exp_date_day}/#{sub.creditcard.year}".to_time
      next unless cc_exp_date < (Time.now + 3.months)
      
      #checks for credit cards due to expiry with all the following ranges
      [1.day, 3.days, 1.week, 2.weeks, 3.weeks, 1.month, 2.months, 3.months].each do |interval|
	within =  distance_of_time_in_words(Time.now, Time.now + interval)
	
	#TODO:yacin: fix this
	#if cc_exp_date < (Time.now + interval) && sub.end_date.to_time > (Time.now + interval) 
	if cc_exp_date < (Time.now + interval) 
	  
	  unless ExpiryNotification.exists?(:subscription_id => sub.id, :interval => interval.seconds.to_i)
	    notification = ExpiryNotification.create(:subscription_id => sub.id, :interval => interval.seconds)
	    SubscriptionMailer.deliver_expiry_warning(sub, within)
	    @report[:reminded] += 1
	  end

	  break
	end
      end
      
      #final check if credit card has actually expired
      if cc_exp_date < Time.now 
	sub.expire
	SubscriptionMailer.deliver_creditcard_expired(sub)
	@report[:expired] += 1
      end
      
    end
  end
end
