include ActionView::Helpers::DateHelper

class SubscriptionManager
  
  def SubscriptionManager.process()
    report = {:active => 0, :processed => 0,:reminded => 0, :expired => 0}
    subscriptions = Subscription.find(:all, :conditions => {:state => 'active'})
    subscriptions.empty? ? (return report) : (report[:active] = subscriptions.size)
    report[:processed] = check_for_renewals(subscriptions)
    report[:expired] = check_for_creditcard_expiry(subscriptions)
    report
  end
  
  def SubscriptionManager.check_for_renewals(subscriptions)
    nb_payments = 0
    debugger
    subscriptions.each do |sub|
      next unless sub.due_on.to_time <= Time.now()
      #subscription due for renewal
      
      #re-curring payment
      amount = sub.variant.price * 100
      gateway = Gateway.find(:first, :conditions => {:active => true, :environment => ENV['RAILS_ENV']})
      response = gateway.purchase(amount, sub.payment_profile_key)
      puts response.to_yaml
      if response.success?
	payment = CreditcardPayment.create(:subscription => sub, :amount => sub.variant.price,
					   :type => "CreditcardPayment", :creditcard => sub.creditcard)
	payment.creditcard_txns << CreditcardTxn.new(
						     :amount => amount,
						     :response_code => response.authorization,
						     :txn_type => CreditcardTxn::TxnType::PURCHASE
						     )
	subscription.payments << payment
	nb_payments = nb_payments+1
	SubscriptionMailer.deliver_payment_receipt(sub)
      end
    end
    nb_payments
  end
  
  def SubscriptionManager.check_for_creditcard_expiry(subscriptions)
    nb_notice = 0
    subscriptions.each do |sub|
      cc_exp_date_day = Time.parse("#{sub.creditcard.month}/#{sub.creditcard.year}").end_of_month
      cc_exp_date = "#{sub.creditcard.month}/#{cc_exp_date_day}/#{sub.creditcard.year}".to_time
	
      next unless cc_exp_date < (Time.now + 3.months)
      
      #checks for credit cards due to expiry with all the following ranges
      [1.day, 3.days, 1.week, 2.weeks, 3.weeks, 1.month, 2.months, 3.months].each do |interval|
	within =  distance_of_time_in_words(Time.now, Time.now + interval)
	
	if cc_exp_date < (Time.now + interval) && sub.end_date.to_time > (Time.now + interval) 
	  
	  unless ExpiryNotification.exists?(:subscription_id => sub.id, :interval => interval.seconds.to_i)
	    notification = ExpiryNotification.create(:subscription_id => sub.id, :interval => interval.seconds)
	    SubscriptionMailer.deliver_expiry_warning(sub, within)
	    nb_notice = nb_notice+1
	  end

	  break
	end
      end
      
      #final check if credit card has actually expired
      if cc_exp_date < Time.now 
	sub.expire
	SubscriptionMailer.deliver_creditcard_expired(sub)
	nb_notice = nb_notice+1
      end
      
    end
    nb_notice
  end
end
