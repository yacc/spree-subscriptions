SUMMARY
=======

This extension allows you to make variants subscribable and uses it's own internal billing process to handle the recurring charges. It relies on your payment gateway provider's credit card storage API to save credit card details and then uses a cron job to handle payments (and credit card expiry notifications).

This extension does not use pre-canned recurring billing functionality from third-party gateways, as we feel our approach is more flexible while still remaining PCI compliant.
 
INSTALLATION
------------

1. Install this extension

    `script/extension install git://github.com/yacc/spree-subscriptions.git`

2. Run pending migrations

    `rake db:migrate`


3. The extension includes a whenever (gem) schedule to setup a cron job to process billing / notifications, to generate the cron job run the following:

    `whenever --load-file -w vendor/extensions/subscriptions/config/schedule.rb`
			
4. Using the admin interface you should now have a "Subscribable" drop-down list when adding / editing variants. If you select True on this drop down and then set the subscription option types which are:
	
	Duration: The number of intervals between subscription renewals (charges).
	
	Interval: This can be either "Month" or "Year", combined with the duration above to calculate how often a subscription is renewed (charged).
	
	For example:
	. Duration=1 and Interval=month: montly recurring payment 
	. Duration=1 and Interval=year:  yearly recurring payment 
 
DEVELOPMENT:
------------
If you need to debug the recurring payments - maybe because you're using a non tested gateway - follow these steps:
1. Start a Rails console, and:
  RAILS_ENV=development script/console (--debugger if you're planning on using the debugger to step in the code)
2. Start the SubscriptionManager
  SubscriptionManager.process


TESTING:
--------

After installing the extension, create and migrate your test database, then cd to the extension directory and type: `rake spec`.	

NOTES
-----

This extension has only been tested with the Beanstream Gateway. Your payment gateway will need support the following methods:

*	.store - For saving credit card details and returning a payment profile identifier
*	.purchase - The purchase method needs to accept the payment profile identifier as a parameter.

If the ActiveMerchant implementation for your chosen gateway doesn't support these methods you can include then in the Spree Gateway wrapper, take a look at the Beanstream gateway class in Spree core in (vendor/extensions/payment_gateway/app/models/gateway/beanstream.rb).


Subscriptions never expire provided a valid credit card is kept on file.


The cron job will notify users of expiring credit cards, and will "expire" subscriptions if no new card details are provided when a subscription renewal is due.

SHOP SETTINGS:
--------------
You might want to define a shipping and a tax category for your service plan.
Also, you'll have to define new option types for your new subscribable product:
      subscription-duration	Duration	 
      subscription-interval	Interval
Then, add a new variant to yur product as decribe earlier.

TODO:
-----
1. Make sure we handle well case where variant of subscription is modified
2. Subscription are not available to guest, you have to login to buy a subscription
